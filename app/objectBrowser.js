import * as React from 'react';
import * as _  from './core';


function isSimple(o) {
  return o == null || _.isNumber(o) || _.isBoolean(o) || _.isString(o);
}

function componentForObject(o) {
  if (_.isUndefined(o)) {
    return <span className='cm-atom'>undefined</span>;
  } else if (o == null) {
    return <span className='cm-atom'>null</span>;
  } else if (_.isNumber(o)) {
    return <span className='cm-number'>{o}</span>;
  } else if (_.isBoolean(o)) {
    return <span className='cm-atom'>{o ? 'true' : 'false'}</span>;
  } else if (_.isString(o)) {
    return <span className='cm-string' style={{whiteSpace: 'pre'}}>"{o}"</span>;
  } else if (o instanceof Date) {
    return <span>{o.toString()}</span>;
  } else {
    return null;
  }
}

const Toggleable = {
  getInitialState() {
    return {open: this.props.initiallyOpen || false};
  },

  toggle(e) {
    e.stopPropagation();
    this.setState({open: !this.state.open});
  },

  toggleClass() {
    return this.state.open
      ? 'fa-caret-down'
      : 'fa-caret-right';
  }
};

const Spacer = <i className='fa fa-fw'/>;

const Var = React.createClass({
  render() {
    return <span className='cm-variable'>{this.props.children}</span>;
  }
});

const Punct = React.createClass({
  render() {
    return <span className='cm-punctuation'>{this.props.children}</span>;
  }
});

export const ObjectBrowserComponent = React.createClass({
  getDefaultProps() {
    return {showProto: true};
  },

  childContextTypes: {
    showProto: React.PropTypes.bool.isRequired
  },

  getChildContext() {
    return {showProto: this.props.showProto}
  },

  render() {
    const {object} = this.props;
    let browser;

    if (isSimple(object)) {
      browser = componentForObject(object);
    } else if (_.isArray(this.props.object)) {
      browser = <ObjectBrowserTopLevelArrayComponent object={object}/>;
    } else {
      browser = <ObjectBrowserTopLevelObjectComponent object={object}/>;
    }

    return <div className='object-browser'>{browser}</div>;
  }
});


const TopLevelComponent = React.createClass({
  mixins: [Toggleable],

  render() {
    const inside = this.state.open
      ? (
        <div>
          {Spacer}
          <ObjectBrowserEntriesComponent object={this.props.object}/>
        </div>
      )
      : null;

    return (
      <div>
        <div onClick={this.toggle}>
          <i className={`fa fa-fw ${this.toggleClass()}`}/>
          {this.props.children}
        </div>
        {inside}
      </div>
    );
  }
});

const ObjectBrowserTopLevelObjectComponent = React.createClass({
  render() {
    const {object} = this.props;

    // TODO only ownProperties
    const children = Object.keys(object).slice(0, 5).map((key) => {
      let child;
      try {
        child = <ObjectBrowserSummaryComponent object={object[key]}/>;
      } catch (e) {
        child = '(error in getter)';
      }

      return (
        <span>
          <Var>{key}</Var>
          <Punct>: </Punct>
          {child}
        </span>
      );
    });

    return (
      <TopLevelComponent object={object}>
        <span>
          <Var>Object </Var>
          <Punct>{'{'}</Punct>
          {_.intersperse(children, <Punct>, </Punct>)}
          <Punct>{'}'}</Punct>
        </span>
      </TopLevelComponent>
    );
  }
});

const ObjectBrowserTopLevelArrayComponent = React.createClass({
  render() {
    const children = this.props.object.slice(0, 20).map((v) => (
      <ObjectBrowserSummaryComponent object={v}/>
    ));

    return (
      <TopLevelComponent object={this.props.object}>
        <span>
          <Punct>[</Punct>
          {_.intersperse(children, <Punct>, </Punct>)}
          <Punct>]</Punct>
        </span>
      </TopLevelComponent>
    );
  }
});

const ObjectBrowserEntriesComponent = React.createClass({
  contextTypes: {
    showProto: React.PropTypes.bool.isRequired
  },

  getInitialState() {
    return {visibleEntries: 50};
  },

  expand(e) {
    e.stopPropagation();
    this.setState({visibleEntries: this.state.visibleEntries * 2});
  },

  render() {
    const {object} = this.props;
    const proto = Object.getPrototypeOf(object);
    const propertyNames = _.without(Object.getOwnPropertyNames(object), '__proto__');

    const children = propertyNames.slice(0, this.state.visibleEntries).map((key) => {
      let value;
      try {
        value = object[key];
      } catch (e) {
        value = null;
      }

      const enumerable = Object.getOwnPropertyDescriptor(object, key).enumerable;
      return <ObjectBrowserEntryComponent key={key} value={value} enumerable={enumerable}/>;
    });

    const showMore = propertyNames.length > this.state.visibleEntries
      ? <div onClick={this.expand} className='run-button'>Show more</div>
      : null;

    const protoChild = proto != null && this.context.showProto
      ? <ObjectBrowserEntryComponent key='__proto__' value={proto} own={false}/>
      : null;

    return (
      <div style={{display: 'inline-block'}}>
        {children}
        {showMore}
        {protoChild}
      </div>
    );
  }
});

const ObjectBrowserEntryComponent = React.createClass({
  mixins: [Toggleable],

  render() {
    const {key, value, enumerable} = this.props

    const className =  enumerable ? '' : 'non-enumerable-property';

    const summary = (
      <div style={{display: 'inline-block'}}>
        <ObjectBrowserSummaryComponent object={value}/>
      </div>
    );

    if (isSimple(value)) {
      return (
        <div>
          <div style={{display: 'inline-block', verticalAlign: 'top', marginRight: '0.5em'}}>
            {Spacer}
            <span className={className}><Var>{key}</Var><Punct>:</Punct></span>
          </div>
          {summary}
        </div>
      );
    } else {
      const inside = this.state.open
        ? (
          <div>
            {Spacer}
            <ObjectBrowserEntriesComponent object={value}/>
          </div>
        )
        : null;

      return (
        <div>
          <div onClick={this.toggle}>
            <div style={{display: 'inline-block', verticalAlign: 'top', marginRight: '0.5em'}}>
              <i className={`fa fa-fw ${this.toggleClass()}`}/>
              <span className={className}><Var>{key}</Var><Punct>:</Punct></span>
            </div>
            {summary}
          </div>
          {inside}
        </div>
      );
    }
  }
});

const ObjectBrowserSummaryComponent = React.createClass({
  render() {
    const c = componentForObject(this.props.object)
    if (c != null) {
      return c;
    } else {
      let name = this.props.object.constructor ? this.props.object.constructor.name : null;
      if (!name || name == '') {
        name = '(anonymous constructor)';
      }
      if (_.isArray(this.props.object)) {
        name += `[${this.props.object.length}]`;
      }

      return <Var>{name}</Var>;
    }
  }
});
