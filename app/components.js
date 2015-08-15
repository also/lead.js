import CodeMirror from 'codemirror';
import 'codemirror/addon/runmode/runmode';
import React from 'react/addons';

import {ContextAwareMixin} from './contextComponents';

const formatCode = function (code, language, target) {
  if (CodeMirror.runMode != null) {
    let opts;
    if (language === 'json') {
      opts = {
        name: 'javascript',
        json: true
      };
    } else {
      opts = {
        name: language
      };
    }
    CodeMirror.runMode(code, opts, target);
  } else {
    target.textContent = code;
  }
};

export const ExampleComponent = React.createClass({
  displayName: 'ExampleComponent',

  mixins: [ContextAwareMixin],

  getDefaultProps() {
    return {
      language: 'coffeescript'
    };
  },

  render() {
    return <div className='example'>
      <SourceComponent {...this.props}/>
      <span className='run-button' onClick={this.onClick}>
        <i className='fa fa-play-circle'/>
        {' '}
        Run this example
      </span>
    </div>;
  },

  onClick() {
    if (this.props.run) {
      return this.state.ctx.run(this.props.value);
    } else {
      return this.state.ctx.set_code(this.props.value);
    }
  }
});

export const SourceComponent = React.createClass({
  displayName: 'SourceComponent',

  renderCode() {
    const value = this.props.displayValue != null ? this.props.displayValue : this.props.value;
    return formatCode(value, this.props.language, this.getDOMNode());
  },

  render() {
    return React.DOM.pre();
  },

  componentDidMount() {
    return this.renderCode();
  },

  componentDidUpdate() {
    return this.renderCode();
  }
});

export const ToggleComponent = React.createClass({
  displayName: 'ToggleComponent',

  getInitialState() {
    return {
      open: this.props.initiallyOpen || false
    };
  },

  toggle(e) {
    e.stopPropagation();
    return this.setState({
      open: !this.state.open
    });
  },

  render() {
    const toggleClass = this.state.open ? 'fa-caret-down' : 'fa-caret-right';

    const body = !this.state.open ? null : <div>
      <i className='fa fa-fw'/>
      <div className='toggle-body'>{this.props.children}</div>
    </div>;

    return <div className='toggle-component'>
      <div className='toggle' onClick={this.toggle}>
        <i className={'fa fa-fw ' + toggleClass}/>
        <div className='toggle-title'>{this.props.title}</div>
        {body}
      </div>
    </div>;
  }
});

const OBSERVABLE_KEY = Symbol('observable');
const UNSUBSCRIBE_KEY = Symbol('unsubscribe');

export const ObservableMixin = {
  _getObservable(props, context) {
    if (this.getObservable) {
      return this.getObservable(props, context);
    } else {
      return props.observable;
    }
  },

  getInitialState() {
    return {value: null, error: null};
  },

  componentWillMount() {
    return this.init(this._getObservable(this.props, this.context));
  },

  componentWillReceiveProps(nextProps, nextContext) {
    const observable = this._getObservable(nextProps, nextContext);

    if (this[OBSERVABLE_KEY] !== observable) {
      return this.init(observable);
    }
  },

  init(observable) {
    if (this[UNSUBSCRIBE_KEY]) {
      this[UNSUBSCRIBE_KEY]();
    }

    this[OBSERVABLE_KEY] = observable;
    this[UNSUBSCRIBE_KEY] = observable.subscribe((event) => {
      if (event.isError()) {
        try {
          this.setState({
            error: event.error
          });
        } catch (e) {
          // TODO what's the right way to handle this?
          console.error(e);
        }
      } else if (event.hasValue()) {
        try {
          this.setState({
            value: event.value(),
            error: null
          });
        } catch (e) {
          console.error(e);
        }
      }
    });
  },

  componentWillUnmount() {
    return this[UNSUBSCRIBE_KEY]();
  }
};

export const SimpleLayoutComponent = React.createClass({
  displayName: 'SimpleLayoutComponent',

  mixins: [React.addons.PureRenderMixin],

  render() {
    return <div>{this.props.children}</div>;
  }
});

export const PropsModelComponent = React.createClass({
  displayName: 'PropsModelComponent',

  mixins: [ObservableMixin],

  getObservable() {
    return this.props.child_props;
  },

  render() {
    return this.props.constructor(this.state.value);
  }
});
