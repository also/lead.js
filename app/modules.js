/* eslint-disable camelcase */

import Q from 'q';
import _ from 'underscore';
import Settings from './settings';

let Context = null;

function _export(exports, module_name, definition_fn) {
  const settings = Settings.with_prefix(module_name);
  const contextExports = {};
  const docs = [];

  docs.push({
    key: module_name,
    doc: {index: true}
  });

  const doc = function (name, summary, complete) {
    return docs.push({
      key: [module_name, name],
      doc: {summary, complete}
    });
  };

  function optDocFn(f) {
    return (...args) => {
      if (_.isString(args[1])) {
        const [name, summary] = args;
        doc(name, summary);
        args.splice(1, 1);
      }
      return f(...args);
    };
  }

  const fn = optDocFn((name, f, cmd_f) => {
    contextExports[name] = {
      module_name,
      fn: f,
      cmd_fn: cmd_f,
      name
    };
  });

  const cmd = optDocFn((name, wrapped) => {
    return fn(name, wrapped, wrapped);
  });

  const component_fn = optDocFn((name, f) => {
    const wrapped = (ctx, ...args) => {
      return Context.add_component(ctx, f(ctx, ...args));
    };

    wrapped.raw_fn = f;
    return fn(name, wrapped);
  });

  const component_cmd = optDocFn((name, f) => {
    const wrapped = function (ctx, ...args) {
      return Context.add_component(ctx, f(ctx, ...args));
    };

    wrapped.raw_fn = f;
    return cmd(name, wrapped);
  });

  function contextExport(...args) {
    if (args.length === 1) {
      return _.extend(contextExports, arguments[0]);
    } else {
      const [k, v] = args;
      contextExports[k] = v;
    }
  }

  const componentCmd = component_cmd;
  const componentFn = component_fn;

  const helpers = {
    doc: doc,
    cmd: cmd,
    fn: fn,
    component_cmd: component_cmd,
    component_fn: component_fn,
    componentCmd: componentCmd,
    componentFn: componentFn,
    contextExport: contextExport,
    settings: settings
  };

  return _.extend(exports, {
    contextExports: contextExports,
    docs: docs
  }, definition_fn(helpers));
}

export {_export as export};

export function collect_extension_points(modules, ep) {
  return _.flatten(_.compact(_.pluck(modules, ep)));
}

export function init_modules(modules) {
  const Documentation = require('./documentation');

  Context = require('./context');

  const promises = _.map(modules, mod => {
    let promise;
    if (mod.init != null) {
      promise = Q(mod.init()).then(function () {
        return mod;
      });
    } else {
      promise = Q(mod);
    }

    return promise.then(mod => {
      if (mod.docs != null) {
        return _.each(mod.docs, ({key, doc}) => {
          return Documentation.register(key, doc);
        });
      }
    });
  });

  return Q.all(promises).then(function () {
    return modules;
  });
}
