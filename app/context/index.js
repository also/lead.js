import React from 'react/addons';
import _ from 'underscore';
import Bacon from 'bacon.model';

import ContextComponent from './ContextComponent';
import {SimpleLayoutComponent} from '../components';
import * as Builtins from '../builtins';
import * as Modules from '../modules';

import {addComponent, removeAllComponents, componentList} from '../componentList';
import {scopedEval} from '../scripting/eval';
import displayObject from '../displayObject';

export {scopedEval as scoped_eval};
export {addComponent as add_component};
export {removeAllComponents as remove_all_components};

export const IGNORE = Symbol('ignore');

const SCRIPTING_FN_VALUE = Symbol('scripting function value');

const SCRIPTING = Symbol('scripting');


let runningContextBinding = null;

export const value = function (v) {
  return {
    [SCRIPTING_FN_VALUE]: v
  };
};

export const isValue = function (v) {
  return v && v.hasOwnProperty(SCRIPTING_FN_VALUE);
};

export const unwrapValue = function (v) {
  return v[SCRIPTING_FN_VALUE];
};

export function scriptingInfo(o) {
  return o[SCRIPTING];
}

export const collect_extension_points = function (context, extensionPoint) {
  return Modules.collect_extension_points(context.modules, extensionPoint);
};

// extension point
export const resolveDocumentationKey = function (ctx, o) {
  if (o && o[SCRIPTING]) {
    if (o[SCRIPTING].fn) {
      const fn = o[SCRIPTING].fn;
      return [fn.module_name, fn.name];
    } else {
      return o[SCRIPTING].name;
    }
  }
};

class LeadNamespace {}

const collectScriptingExports = function (context) {
  return _.object(_.map(context.modules, (module, name) => {
    if (!module) {
      throw new Error('Module ' + name + ' is invalid');
    }

    return [name, Object.assign(new LeadNamespace(), module.scriptingExports)];
  }));
};

export const isRunContext = function (o) {
  return (o != null ? o.componentList : void 0) != null;
};

const bindFnToContext = function (ctx, fn) {
  return (...args) => {
    args.unshift(ctx);
    return fn.apply(ctx, args);
  };
};

// define a getter for every scripting function that binds to the current scope on access.
// copy everything else.
const lazilyBindScriptingFns = function (target, scope, fns, namePrefix='') {
  const doBind = function (k, o) {
    if ((o != null) && _.isFunction(o.fn)) {
      const name = namePrefix + k;

      const wrappedFn = function () {
        const wrappedResult = o.fn.apply(null, arguments);
        // ignore return values except for special {SCRIPTING_FN_VALUE}
        return isValue(wrappedResult) ? unwrapValue(wrappedResult) : IGNORE;
      };

      const bind = function () {
        const bound = bindFnToContext(scope.ctx, wrappedFn);
        bound[SCRIPTING] = {fn: o, name};
        return bound;
      };

      return Object.defineProperty(target, k, {
        get: bind,
        enumerable: true
      });
    } else {
      if (o instanceof LeadNamespace) {
        target[k] = lazilyBindScriptingFns({
          [SCRIPTING]: {name: k}
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

// the base context contains the loaded modules, and the list of modules to import into every context
export const create_base_context = function (ctx) {
  let {modules} = ctx;
  // TODO not really cool to reference exports here
  modules = Object.assign({
    context: exports,
    builtins: Builtins
  }, modules);

  // TODO find a better home for repl vars
  return Object.assign({}, ctx, {modules, scripting: {replVars: {}}});
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

export const createScriptExecutionContext = function (extraContexts) {
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
// TODO only used by input
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

// the "script static context" context contains all the scripting functions and vars. basically, everything needed to support
// an editor
export const createScriptStaticContext = function (base) {
  const scriptingExports = collectScriptingExports(base);
  const imported = _.clone(scriptingExports);
  _.each(base.imports, _.partial(importInto, scriptingExports, imported));

  const scope = {
    _capture_context(fn) {
      const restoringContext = captureContext(scope.ctx);
      return (...args) => {
        return restoringContext(() => fn.apply(this, args));
      };
    }
  };

  lazilyBindScriptingFns(scope, scope, imported);

  return Object.assign({}, base, {imported, scope});
};

export const createStandaloneScriptContext = function (ctx) {
  const {imports=[]} = ctx;
  const baseContext = create_base_context(Object.assign({}, ctx, {imports: ['builtins.*'].concat(imports)}));

  return createScriptExecutionContext([createScriptStaticContext(baseContext)]);
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
