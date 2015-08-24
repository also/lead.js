import Q from 'q';
import _ from 'underscore';
import * as Settings from './settings';

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
    return (name, ...args) => {
      if (_.isString(args[0])) {
        const [summary] = args;
        doc(name, summary);
        args = args.slice(1);
      }
      return f(name, ...args);
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

  const componentFn = optDocFn((name, f) => {
    const wrapped = (ctx, ...args) => {
      return Context.add_component(ctx, f(ctx, ...args));
    };

    return fn(name, wrapped);
  });

  const componentCmd = optDocFn((name, f) => {
    const wrapped = function (ctx, ...args) {
      return Context.add_component(ctx, f(ctx, ...args));
    };

    return cmd(name, wrapped);
  });

  function contextExport(...args) {
    if (args.length === 1) {
      return Object.assign(contextExports, arguments[0]);
    } else {
      const [k, v] = args;
      contextExports[k] = v;
    }
  }

  const helpers = {
    doc,
    cmd,
    fn,
    componentCmd,
    componentFn,
    contextExport,
    settings,
    contextExports,
    docs
  };

  return Object.assign(exports, {contextExports, docs}, definition_fn(helpers));
}

export {_export as export};

export function collect_extension_points(modules, ep) {
  return _.flatten(_.compact(_.pluck(modules, ep)));
}

export function init_modules(ctx, modules) {
  const Documentation = require('./documentation');

  Context = require('./context');

  const promises = _.map(modules, (mod) => {
    let promise;
    if (mod.init != null) {
      promise = Q(mod.init(ctx)).then(function () {
        return mod;
      });
    } else {
      promise = Q(mod);
    }

    return promise.then((mod) => {
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
