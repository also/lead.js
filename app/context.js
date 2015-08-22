import _ from 'underscore';
import Bacon from 'bacon.model';
import React from 'react/addons';

import {user_settings, global_settings} from './settings';


import {ContextAwareMixin, ContextRegisteringMixin, ComponentContextComponent} from './contextComponents';
import {ObservableMixin, SimpleLayoutComponent} from './components';
import * as Builtins from './builtins';
import * as Modules from './modules';

import {addComponent, removeAllComponents, componentList} from './componentList';
import {scopedEval} from './contextEval';
import displayObject from './displayObject';

export {scopedEval as scoped_eval};
export {addComponent as add_component};
export {removeAllComponents as remove_all_components};

export const IGNORE = Symbol('ignore');

const CONTEXT_FN_VALUE = Symbol('context function value');

let runningContextBinding = null;

export const value = function (v) {
  return {
    [CONTEXT_FN_VALUE]: v
  };
};

export const isValue = function (v) {
  return v && v.hasOwnProperty(CONTEXT_FN_VALUE);
};

export const unwrapValue = function (v) {
  return v[CONTEXT_FN_VALUE];
};

export const collect_extension_points = function (context, extensionPoint) {
  return Modules.collect_extension_points(context.modules, extensionPoint);
};

// extension point
export const resolveDocumentationKey = function (ctx, o) {
  if (o && o._lead_context_name) {
    if (o._lead_context_fn) {
      const fn = o._lead_context_fn;
      return [fn.module_name, fn.name];
    } else {
      return o._lead_context_name;
    }
  }
};

class LeadNamespace {}

const collectContextExports = function (context) {
  return _.object(_.map(context.modules, function (module, name) {
    if (!module) {
      throw new Error('Module ' + name + ' is invalid');
    }
    const vars = _.isFunction(module.context_vars) ?
      module.context_vars.call(context) :
      module.context_vars;

    return [name, Object.assign(new LeadNamespace(), module.contextExports, vars)];
  }));
};

const isRunContext = function (o) {
  return (o != null ? o.componentList : void 0) != null;
};

const bindFnToContext = function (ctx, fn) {
  return (...args) => {
    args.unshift(ctx);
    return fn.apply(ctx, args);
  };
};

// define a getter for every context function that binds to the current scope on access.
// copy everything else.
const lazilyBindContextFns = function (target, scope, fns, namePrefix='') {
  const doBind = function (k, o) {
    if ((o != null) && _.isFunction(o.fn)) {
      const name = namePrefix + k;

      const wrappedFn = function () {
        const wrappedResult = o.fn.apply(null, arguments);
        // ignore return values except for special {CONTEXT_FN_VALUE}
        return isValue(wrappedResult) ? unwrapValue(wrappedResult) : IGNORE;
      };

      const bind = function () {
        const bound = bindFnToContext(scope.ctx, wrappedFn);
        bound._lead_context_fn = o;
        bound._lead_context_name = name;
        return bound;
      };

      return Object.defineProperty(target, k, {
        get: bind,
        enumerable: true
      });
    } else {
      if (o instanceof LeadNamespace) {
        target[k] = lazilyBindContextFns({
          _lead_context_name: k
        }, scope, o, k + '.');
      } else {
        target[k] = o;
      }
      return target[k];
    }
  };

  for (const k in fns) {
    const o = fns[k];
    doBind(k, o);
  }

  return target;
};

export const find_in_scope = function (ctx, name) {
  return ctx.scope[name];
};

const registerPromise = function (ctx, promise) {
  ctx.asyncs.push(1);
  promise.finally(() => {
    ctx.asyncs.push(-1);
    ctx.changes.push(true);
  });
};

export const AsyncComponent = React.createClass({
  displayName: 'AsyncComponent',

  mixins: [ContextAwareMixin],

  componentWillMount() {
    registerPromise(this.ctx(), this.props.promise);
  },

  componentWillUnmount() {
    // FIXME should unregister
  },

  render() {
    return <div>{this.props.children}</div>;
  }
});

export const ContextComponent = React.createClass({
  displayName: 'ContextComponent',

  mixins: [ContextRegisteringMixin],

  propTypes: {
    ctx(c) {
      if (!isRunContext(c.ctx)) {
        throw new Error('context required');
      }
    }
  },

  render() {
    return <ContextLayoutComponent ctx={this.props.ctx}/>;
  }
});

const ContextLayoutComponent = React.createClass({
  displayName: 'ContextLayoutComponent',

  mixins: [ObservableMixin],

  propTypes: {
    ctx(c) {
      if (!isRunContext(c.ctx)) {
        throw new Error('context required');
      }
    }
  },

  getObservable(props) {
    return props.ctx.componentList.model;
  },

  render() {
    const {ctx} = this.props;

    const children = _.map(this.state.value, ({key, component}) => {
      let c;

      if (_.isFunction(component)) {
        c = component();
      } else {
        c = component;
      }

      return React.addons.cloneWithProps(c, {key});
    });

    return React.createElement(ctx.layout, Object.assign({children}, ctx.layout_props));
  }
});

export const ContextOutputComponent = React.createClass({
  displayName: 'ContextOutputComponent',

  mixins: [ContextAwareMixin],

  render() {
    return <ContextLayoutComponent ctx={this.ctx()}/>;
  }
});

export const TopLevelContextComponent = React.createClass({
  displayName: 'TopLevelContextComponent',

  getInitialState() {
    // FIXME #175 props can change
    const ctx = create_standalone_context(this.props);
    return {ctx};
  },

  get_ctx() {
    return this.state.ctx;
  },

  render() {
    return <ComponentContextComponent children={this.props.children} ctx={this.state.ctx}/>;
  }
});

// the base context contains the loaded modules, and the list of modules to import into every context
export const create_base_context = function ({modules, imports}={}) {
  // TODO not really cool to reference exports here
  modules = Object.assign({
    context: exports,
    builtins: Builtins
  }, modules);

  // TODO find a better home for repl vars
  return {
    modules: modules,
    imports: imports,
    repl_vars: {},
    prop_vars: {},
    settings: {user: user_settings, global: global_settings}
  };
};

const importInto = function (obj, target, path) {
  const segments = path.split('.');
  const lastSegment = segments[segments.length - 1];
  const wildcard = lastSegment === '*';

  if (wildcard) {
    segments.pop();
  }

  let imported;
  try {
    imported = _.reduce(segments, (result, key) => result[key], obj);
  } catch (e) {
    imported = null;
  }

  if (imported == null) {
    throw new Error("can't import " + path);
  }

  if (wildcard) {
    Object.assign(target, imported);
  } else {
    target[lastSegment] = imported;
  }
};

// TODO this is an awful name
const context_run_context_prototype = {
  options() {
    return this.current_options;
  }
};

export const create_nested_context = function (parent, overrides) {
  const newContext = Object.assign(Object.create(parent), {
    layout: SimpleLayoutComponent
  }, overrides);

  newContext.componentList = componentList();
  newContext.component = function () {
    return <ContextComponent ctx={newContext}/>;
  };
  return newContext;
};

export const create_run_context = function (extraContexts) {
  const run_context_prototype = Object.assign({}, ...extraContexts, context_run_context_prototype);
  const result = create_nested_context(run_context_prototype);
  if (result.mainLayout != null) {
    result.layout = result.mainLayout;
  }
  const asyncs = new Bacon.Bus();
  const changes = new Bacon.Bus();
  changes.plug(result.componentList.model);
  _.defaults(result, {
    current_options: {},
    changes: changes,
    asyncs: asyncs,
    pending: asyncs.scan(0, (a, b) => a + b)
  });

  result.scope.ctx = result;

  return result;
};

const spliceCtx = function (ctx, targetCtx, fn, args=[]) {
  const previousContext = targetCtx.scope.ctx;
  targetCtx.scope.ctx = ctx;
  fn = fn._lead_unbound_fn || fn;
  try {
    return fn(ctx, ...args);
  } finally {
    targetCtx.scope.ctx = previousContext;
  }
};

const callInCtx = function (ctx, fn, args) {
  return spliceCtx(ctx, ctx, fn, args);
};

// creates a nested context, adds it to the component list, and applies the function to it
export const nested_item = function (ctx, fn, ...args) {
  const nested = create_nested_context(ctx);
  addComponent(ctx, nested.component);
  return callInCtx(nested, fn, args);
};

export const callUserFunctionInCtx = function (ctx, fn, args=[]) {
  fn = fn._lead_unbound_fn || fn;
  spliceCtx(ctx, ctx, () => fn(...args));
};

// returns a function that calls its argument in the current context
const captureContext = function (ctx) {
  const runningContext = runningContextBinding;

  return (fn, args) => {
    const previousRunningContextBinding = runningContextBinding;
    runningContextBinding = runningContext;
    try {
      return callInCtx(ctx, fn, args);
    } finally {
      runningContextBinding = previousRunningContextBinding;
    }
  };
};

// TODO only used by test
// wraps a function so that it is called in the current context
export const keeping_context = function (ctx, fn) {
  const restoringContext = captureContext(ctx);

  return () => {
    return restoringContext(fn, arguments);
  };
};

// TODO only used by test
export const in_running_context = function (ctx, fn, args) {
  if (runningContextBinding == null) {
    throw new Error('no active running context. did you call an async function without keeping the context?');
  }
  return spliceCtx(runningContextBinding, ctx, fn, args);
};

// the XXX context contains all the context functions and vars. basically, everything needed to support
// an editor
export const create_context = function (base) {
  const contextExports = collectContextExports(base);
  const imported = _.clone(contextExports);
  _.each(base.imports, _.partial(importInto, contextExports, imported));

  const scope = {
    _capture_context(fn) {
      const restoringContext = captureContext(scope.ctx);
      return (...args) => {
        return restoringContext(() => fn.apply(this, args));
      };
    }
  };

  lazilyBindContextFns(scope, scope, imported);

  return Object.assign({}, base, {imported, scope});
};

export const create_standalone_context = function ({imports, modules, context}={}) {
  const baseContext = create_base_context({
    imports: ['builtins.*'].concat(imports || []),
    modules: modules
  });

  return create_run_context([context != null ? context : {}, create_context(baseContext)]);
};

export const run_in_context = function (runContext, fn) {
  const previousRunningContextBinding = runningContextBinding;

  try {
    runningContextBinding = runContext;
    const result = callInCtx(runContext, fn);
    return displayObject(runContext, result);
  } finally {
    runningContextBinding = previousRunningContextBinding;
  }
};

export const eval_in_context = function (runContext, string) {
  return run_in_context(runContext, (ctx) => scopedEval(ctx, string));
};
