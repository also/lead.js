import _ from 'underscore';
import React from 'react';

import Markdown from './markdown';
import modules from './modules';
import * as Documentation from './documentation';
import * as Components from './components';
import * as Context from './context';
import * as ContextComponents from './contextComponents';
import App from './app';
import {ObjectBrowserComponent} from './objectBrowser';

const {ExampleComponent} = Components;

export {ExampleComponent as ExampleComponent, ObjectBrowserComponent as ObjectBrowserComponent};

export const help_component = function(ctx, o) {
  const key = Documentation.getKey(ctx, o);

  if (key != null) {
    const doc = Documentation.getDocumentation(key);

    return <Documentation.DocumentationItemComponent {...{ctx, doc}}/>;
  } else {
    if (_.isString(o)) {
      // TODO shouldn't be pre
      return <pre>Documentation for {o} not found.</pre>;
    } else {
      return <pre>Documentation not found.</pre>;
    }
  }
};

export const ObjectComponent = React.createClass({
  displayName: 'ObjectComponent',
  render() {
    let s;
    try {
      s = JSON.stringify(this.props.object, null, '  ');
    } catch (_error) {
      s = null;
    }

    if (!s) {
      try {
        s = '' + this.props.object;
      } catch (_error) {
        s = `"(object can't be converted to a string)"`;
      }
    }

    return <Components.SourceComponent value={s} language="json"/>;
  }
});

const HtmlComponent = React.createClass({
  displayName: 'HtmlComponent',

  render() {
    return <div className="user-html" dangerouslySetInnerHTML={{__html: this.props.value}}/>;
  }
});

export const ErrorComponent = React.createClass({
  displayName: 'ErrorComponent',

  mixins: [ContextComponents.ContextAwareMixin],

  render() {
    const errorRenderers = Context.collect_extension_points(this.state.ctx, 'renderError');
    let message = null;

    _.find(errorRenderers, (renderer) => {
      message = renderer(this.props.message);
    });

    if (!message) {
      message = this.props.message;

      if (message == null) {
        message = <pre>Unknown error</pre>;
      } else if (message instanceof Error) {
        // TODO include stack trace?
        message = <pre>{message.toString()}</pre>;
      } else if (!_.isString(message)) {
        message = <ObjectBrowserComponent object={message}/>;
      }
    }

    return <div className="error">{message}</div>;
  }
});

export const PromiseResolvedComponent = React.createClass({
  displayName: 'PromiseResolvedComponent',

  getInitialState() {
    // FIXME #175 props can change
    this.props.promise.then((v) => {
      this.setState({
        value: v,
        resolved: true
      });
    });

    return {
      value: null,
      resolved: false
    };
  },

  render() {
    if (this.state.resolved) {
      return <div>{this.props.constructor(this.state.value)}</div>;
    } else {
      return null;
    }
  }
});

export const PromiseStatusComponent = React.createClass({
  displayName: 'PromiseStatusComponent',

  render() {
    let text;
    let icon;

    if (this.state && this.state.duration) {
      const ms = this.state.duration;

      const duration = ms >= 1000 ? `${(ms / 1000).toFixed(1)} s`: `${ms} ms`;
      if (this.props.promise.isFulfilled()) {
        text = 'Loaded in ' + duration;
        icon = '';
      } else {
        text = 'Failed after ' + duration;
        icon = 'fa-exclamation-triangle';
      }
    } else {
      text = 'Loading';
      icon = 'fa-spinner fa-spin';
    }

    return <div className="promise-status">
      <i className={`fa ${icon} fa-fw`}/>
      {' '}
      {text}
    </div>;
  },

  getInitialState() {
    // FIXME #175 props can change
    if (this.props.promise.isPending()) {
      return null;
    } else {
      return {
        duration: 0
      };
    }
  },

  finished() {
    this.setState({
      duration: new Date() - this.props.start_time
    });
  },

  componentWillMount() {
    // TODO this should probably happen earlier, in case the promise finishes before componentWillMount
    this.props.promise.finally(this.finished);
  }
});

export const ComponentAndError = React.createClass({
  displayName: 'ComponentAndError',

  componentWillMount() {
    this.props.promise.fail((e) => {
      this.setState({
        error: e
      });
    });
  },

  getInitialState() {
    return {
      error: null
    };
  },

  render() {
    let error = null;

    if (this.state.error != null) {
      error = <ErrorComponent message={this.state.error}/>;
    }

    return <div>
      {this.props.children}
      {error}
    </div>;
  }
});

export const ObservableComponent = React.createClass({
  displayName: 'ObservableComponent',

  mixins: [Components.ObservableMixin],

  render() {
    let valueComponent;

    if (this.state.value != null) {
      valueComponent = <ObjectBrowserComponent object={this.state.value}/>;
    } else {
      valueComponent = '(no value)';
    }

    return <Components.ToggleComponent title='Live Value'>
      {valueComponent}
    </Components.ToggleComponent>;
  }
});

export const PromiseComponent = React.createClass({
  displayName: 'PromiseComponent',

  getInitialState() {
    this.props.promise.finally(() => {
      this.setState({
        snapshot: this.props.promise.inspect()
      });
    });

    return {
      snapshot: this.props.promise.inspect(),
      startTime: new Date()
    };
  },

  render() {
    let title;
    let object = null;

    if (this.state.snapshot.state === 'pending') {
      title = 'Pending Promise';
    } else if (this.state.snapshot.state === 'fulfilled') {
      title = 'Fulfilled Promise';
      object = this.state.snapshot.value;
    } else {
      title = 'Rejected Promise';
      object = this.state.snapshot.reason;
    }

    return <div>
      <Components.ToggleComponent title={title}>
        {object ? <ObjectBrowserComponent object={object}/> : '(no value)'}
      </Components.ToggleComponent>
    </div>;
  }
});

const GridComponent = React.createClass({
  displayName: 'GridComponent',

  propTypes: {
    cols: React.PropTypes.number.isRequired
  },

  render() {
    const {cols} = this.props;
    const rows = [];
    let row = [];

    _.each(this.props.children, (component, i) => {
      if (i % cols === 0) {
        row = [];
        rows.push(row);
      }

      row.push(<div style={{flex: 1}} key={i}>{component}</div>);
    });

    return <div>
      {_.map(rows, (r, i) => <div style={{display: 'flex'}} key={i}>{r}</div>)}
    </div>;
  }
});

export const FlowComponent = React.createClass({
  displayName: 'FlowComponent',

  render() {
    return <div className="flex-layout" style={{display: 'flex', flexWrap: 'wrap'}}>
      {this.props.children}
    </div>;
  }
});

modules.export(exports, 'builtins', function({doc, fn, componentFn, componentCmd}) {
  componentCmd('help', 'Shows this help', (ctx, ...args) => {
    return help_component(ctx, ...args);
  });

  doc('object', 'Displays an object as JSON', '`object` converts an object to a string using `JSON.stringify` if possible and `new String` otherwise.\nThe result is displayed using syntax highlighting.\n\nFor example:\n\n```\nobject a: 1, b: 2, c: 3\n```');
  componentFn('object', (ctx, object) => {
    return <ObjectComponent object={object}/>;
  });

  doc('dir', 'Displays a JavaScript representation of an object', "`dir` displays a JavaScript object's properties.\n\nFor example:\n\n```\ndir 1\n```\n\n```\ndir [1, 2, 3]\n```\n\n```\nclass Class\nc = new Class\nAnonymousClass = ->\nac = new AnonymousClass\nx: {y: z: 1}, n: 2, d: new Date, s: \"xxx\", c: c, ac: ac, un: undefined, t: true\n```");
  componentFn('dir', (ctx, object) => {
    return <ObjectBrowserComponent object={object}/>;
  });

  componentFn('md', 'Displays rendered Markdown', (ctx, string, opts) => {
    return <Markdown.MarkdownComponent value={string} opts={opts}/>;
  });

  componentFn('text', 'Displays text', (ctx, string) => {
    return <p>{string}</p>;
  });

  componentFn('pre', 'Displays preformatted text', (ctx, string) => {
    return <pre>{string}</pre>;
  });

  componentFn('html', 'Displays rendered HTML', (ctx, string) => {
    return <HtmlComponent value={string}/>;
  });

  componentFn('example', 'Displays a code example', (ctx, value, opts={}) => {
    return <ExampleComponent value={value} run={opts.run != null ? opts.run : true}/>;
  });

  componentFn('source', 'Displays source code with syntax highlighting', (ctx, language, value) => {
    return <Components.SourceComponent {...{language, value}}/>;
  });

  fn('options', 'Gets or sets options', (ctx, options) => {
    if (options != null) {
      _.extend(ctx.current_options, options);
    }

    return Context.value(ctx.current_options);
  });

  componentCmd('permalink', 'Create a link to the code in the input cell above', (ctx, code) => {
    if (code == null) {
      code = ctx.previously_run();
    }

    const uri = App.raw_cell_url(ctx, code);

    return <a href={uri}>{uri}</a>;
  });

  componentFn('promise_status', 'Displays the status of a promise', (ctx, promise, startTime) => {
    if (startTime == null) {
      startTime = new Date();
    }

    return <PromiseStatusComponent promise={promise} start_time={startTime}/>;
  });

  componentFn('grid', 'Generates a grid with a number of columns', (ctx, cols, wrappedFn) => {
    const nestedContext = Context.create_nested_context(ctx, {
      layout: GridComponent,
      layout_props: {
        cols: cols
      }
    });

    Context.callUserFunctionInCtx(nestedContext, wrappedFn);

    return nestedContext.component;
  });

  componentFn('flow', 'Flows components next to each other', (ctx, wrappedFn) => {
    const nestedContext = Context.create_nested_context(ctx, {
      layout: FlowComponent
    });

    Context.callUserFunctionInCtx(nestedContext, wrappedFn);

    return nestedContext.component;
  });
});
