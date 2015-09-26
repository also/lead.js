import React from 'react/addons';
import _ from 'underscore';
import Bacon from 'bacon.model';
import Q from 'q';
import URI from 'urijs';

import * as dsl from '../dsl';
import * as Modules from '../modules';
import GraphiteFunctionNames from '../graphite/functions';
import * as http from '../http';
import docs from '../graphite/docs';
//import parser from '../graphite_parser';
import * as Builtins from '../builtins';
import Html from '../html';
import * as Documentation from '../documentation';
import * as Context from '../context';
import AsyncComponent from '../context/AsyncComponent';
import * as Components from '../components';

import FunctionDocsComponent from './FunctionDocsComponent';
import ParameterDocsComponent from './ParameterDocsComponent';
import ServerErrorComponent from './ServerErrorComponent';
import FindResultsComponent from './FindResultsComponent';
import MetricTreeComponent from './MetricTreeComponent';


function getSetting(ctx, ...key) {
  return ctx.settings.global.get('server', ...key);
}

let functionNames = null;
let serverOptionNames = null;

class ServerError {
  constructor(error) {
    this.error = error;
  }
}

export class LeadDataSource {
  constructor(load) {
    this.load = (...args) => Q(load(...args));
  }
}

function buildFunctionDoc(ctx, doc) {
  return <FunctionDocsComponent ctx={ctx} docs={docs.function_docs[doc.function_name]}/>;
}

function buildParameterDoc(ctx, doc) {
  return <ParameterDocsComponent ctx={ctx} docs={docs.parameter_docs[doc.parameterName]}/>;
}

function argsToServerParams(ctx, args) {
  return args_to_params(ctx, {
    args,
    defaultOptions: ctx.options()
  }).server;
}

function renderUrl(ctx, params) {
  return url(ctx, 'render', params);
}

function isPattern(s) {
  return !!s.match(/[*?[{]/);
}

// function parseTarget(string) {
//   return parser.parse(string);
// }

// function parseUrl(string) {
//   const url = new URI(string);
//   const query = url.query(true);
//   let targets = query.target || [];
//
//   if (!_.isArray(targets)) {
//     targets = [targets];
//   }
//   return {
//     targets: _.map(targets, parse_target),
//     options: _.omit(query, 'target')
//   };
// }

function parseErrorResponse(response) {
  if (response.responseJSON != null) {
    return response.responseJSON;
  }

  if (response.responseText == null) {
    return 'request failed';
  }

  const html = Html.parse_document(response.responseText);
  let pre = html.querySelector('pre.exception_value');

  let msg;
  if (pre != null) {
    const h1 = html.querySelector('h1');

    msg = h1.innerText + ': ' + pre.innerText;
  } else {
    pre = html.querySelector('pre');
    msg = pre.innerText.trim();
  }
  return msg != null ? msg : 'Unknown error';
}

function parseFindResponse(query, response) {
  const queryParts = query.split('.');
  const patternParts = queryParts.map(isPattern);

  const results = response.map((node) => node.is_leaf ? node.path : node.path + '.');

  const resultsWithPatterns = results.map((path) => path.split('.').map((matched, i) => {
    return patternParts[i] ? queryParts[i] : matched;
  }).join('.'));

  return _.uniq(resultsWithPatterns.concat(results));
}

function transformResponse(ctx, response) {
  let values;
  if (getSetting(ctx, 'type') === 'lead') {
    if (response.exceptions.length > 0) {
      return Q.reject(new ServerError(response.exceptions));
    }
    if (_.isArray(response.results)) {
      values = response.results.map(({result}) => result);
    } else {
      values = _.values(response.results);
    }

    return _.flatten(values).map(({name, start, step, values, options}) => {
      if (step != null) {
        return {
          target: name,
          datapoints: values.map((v, i) => {
            return [start + step * i, v];
          }),
          options
        };
      } else {
        return {
          target: name,
          datapoints: values,
          options
        };
      }
    });
  } else {
    return response.map(({target, datapoints, options}) => {
      return {
        target,
        datapoints: datapoints.map((arg3) => {
          let ts, v;
          [v, ts] = arg3;
          return [ts, v];
        }),
        options
      };
    });
  }
}

export function getData(ctx, params) {
  return execute(ctx, params).then((response) => transformResponse(ctx, response));
}

export function execute(ctx, params) {
  let promise;
  params.format = 'json';
  if (getSetting(ctx, 'type') === 'lead') {
    promise = http.post(ctx, url(ctx, 'execute'), params);
  } else {
    promise = http.get(ctx, renderUrl(ctx, params));
  }
  return promise.fail(function (response) {
    return Q.reject(new ServerError(parseErrorResponse(response)));
  });
}

export function executeOne(ctx, target, params={}, defaultOptions) {
  const request = batch(ctx, defaultOptions);
  const result = request.add(target);

  request.execute(params);
  return result;
}

export function batch(ctx, defaultOptions) {
  const items = [];

  return {
    add(target) {
      const deferred = Q.defer();

      items.push({
        deferred: deferred,
        target: target
      });
      return deferred.promise;
    },

    execute(params) {
      const targets = _.pluck(items, 'target');

      const args = [targets];

      if (arguments.length === 1) {
        args.push(params);
      }

      return execute(ctx, args_to_params(ctx, {args, defaultOptions}).server)
      .then((result) => {
        if (result.exceptions.length > 0) {
          return Q.reject(new ServerError(result.exceptions));
        }

        result.results.forEach((targetResult, i) => items[i].deferred.resolve(targetResult.result));

        return result;
      }).fail((e) => items.forEach(({deferred}) => deferred.reject(e)));
    }
  };
}

export function complete(ctx, query) {
  return find(ctx, query + '*').then(({result}) => parseFindResponse(query, result));
}

export function find(ctx, query) {
  if (getSetting(ctx, 'type') === 'lead') {
    return http.get(ctx, url(ctx, 'find', {query}))
    .then((response) => {
      const result = response.map((m) => {
        return {
          path: m.name,
          name: m.name,
          is_leaf: m['is-leaf']
        };
      });

      return {query, result};
    });
  } else {
    const params = {query, format: 'completer'};

    return http.get(ctx, url(ctx, 'metrics/find', params)).then((response) => {
      const result = response.metrics.map(({path, name, is_leaf}) => {
        return {
          path: path.replace(/\.$/, ''),
          name,
          is_leaf: is_leaf === '1'
        };
      });

      return {query, result};
    });
  }
}

export function suggest_keys(ctx, s) {
  return _.filter(_.keys(docs.parameter_docs), (k) => k.indexOf(s) === 0);
}

export function args_to_params(ctx, {args, defaultOptions={}}) {
  let lets, options, targets;

  if (args.legnth === 0) {
    return {};
  }

  if (args.length === 1) {
    const [arg] = args;

    targets = arg.targets || arg.target;
    if (targets != null) {
      if (arg.options) {
        options = arg.options;
      } else {
        options = _.clone(arg);
        delete options.targets;
        delete options.target;
      }
    } else {
      targets = args[0];
      options = {};
    }
  } else {
    const last = args[args.length - 1];

    if (_.isString(last) || dsl.is_dsl_node(last) || _.isArray(last)) {
      targets = args;
      options = {};
    } else {
      targets = args;
      options = targets.pop();
    }
  }
  if (!_.isArray(targets)) {
    targets = [targets];
  }

  // flatten one level of nested arrays
  targets = Array.prototype.concat.apply([], targets);

  const serverOptions = Object.assign({},
    _.pick(defaultOptions, serverOptionNames),
    defaultOptions.serverOptions,
    _.pick(options, serverOptionNames),
    options.serverOptions);

  if (serverOptions.from != null) {
    if (serverOptions.start == null) {
      serverOptions.start = serverOptions.from;
    }
    delete serverOptions.from;
  }
  if (serverOptions.until != null) {
    if (serverOptions.end == null) {
      serverOptions.end = serverOptions.util;
    }
    delete serverOptions.util;
  }

  const server = {};

  const target = targets.map((t) => dsl.to_target_string(t, server));

  if (serverOptions.let != null) {
    lets = _.clone(serverOptions.let);
    _.each(lets, (v, k) => {
      lets[k] = dsl.to_target_string(v, server);
    });
  } else {
    lets = {};
  }

  Object.assign(server, serverOptions, {target, lets});

  const client = Object.assign({}, defaultOptions, options, {target, lets});

  return {server, client};
}

export function hasFeature(ctx, feature) {
  return _.contains(getSetting(ctx, 'features') || [], feature);
}

export function resolveDocumentationKey(ctx, o) {
  if (o == null) {
    return null;
  }

  if (_.isFunction(o) && dsl.is_dsl_node(o)) {
    return ['server', 'functions', o.fn_name];
  }
  if (_.isString(o) && docs.parameter_docs[o]) {
    return ['server', 'parameters', o];
  }
}

export function renderError(error) {
  if (error instanceof ServerError) {
    <ServerErrorComponent error={error.error}/>;
  }
}

export function url(ctx, path, params) {
  const baseUrl = getSetting(ctx, 'base_url');

  if (baseUrl == null) {
    throw new Error('Server base_url not set');
  }

  const uri = new URI(baseUrl + '/' + path);

  if (params != null) {
    if (params.start != null || params.end != null) {
      params = Object.assign({}, params);

      if (params.start != null) {
        params.from = params.start;
        delete params.start;
      }
      if (params.end != null) {
        params.until = params.end;
        delete params.end;
      }
    }

    uri.setQuery(params);
  }

  return uri.toString();
}

Modules.export(exports, 'server', ({fn, componentFn, contextExport, doc, contextExports}) => {
  function initDocs() {
    _.sortBy(functionNames, _.identity).forEach((n) => {
      let value;
      const d = docs.function_docs[n];

      if (d != null) {
        value = {
          function_name: n,
          summary: d.signature,
          complete: buildFunctionDoc
        };
      } else {
        value = {
          summary: '(undocumented)'
        };
      }
      const key = ['server', 'functions', n];

      if (!Documentation.getDocumentation(key)) {
        Documentation.register(key, value);
      }
    });

    _.sortBy(serverOptionNames, _.identity).forEach((n) => {
      let value;
      const d = docs.parameter_docs[n];

      if (d != null) {
        value = {
          parameterName: n,
          summary: 'A server parameter',
          complete: buildParameterDoc
        };
      } else {
        value = {
          summary: '(undocumented)'
        };
      }
      Documentation.register(['server', 'parameters', n], value);
    });
  }

  Documentation.register(['server', 'functions'], {index: true});
  Documentation.register(['server', 'parameters'], {index: true});

  doc('q', 'Escapes a metric query', 'Use `q` to reference a metric name in the DSL.\n\nThe Graphite API uses unquoted strings to specify metric names and patterns.\nThe string argument to `q` will be passed directly to the API.\n\nFor example, `sumSeries(q(\'twitter.*.tweetcount\'))` will be sent as `sumSeries(twitter.*.tweetcount)`.');
  fn('q', (ctx, ...targets) => {
    targets.forEach((t) => {
      if (!_.isString(t)) {
        throw new TypeError(t + ' is not a string');
      }
    });

    return Context.value(new dsl.type.q(...targets.map(String)));
  });

  doc('params',
    'Generates the parameters for a render API call',
    '`params` interprets its arguments in the same way as [`get_data`](help:server.get_data),\nbut simply returns the arguments that would be passed to the API.\n\nFor example:\n```\noptions areaMode: \'stacked\'\nobject params sumSeries(q(\'twitter.*.tweetcount\')), width: 1024, height: 768\n```');
  fn('params', (ctx, ...args) => {
    return Context.value(argsToServerParams(ctx, args));
  });

  // componentFn('url', 'Generates a URL for a graph image', ([ctx, ...args]) => {
  //   const params = argsToServerParams(ctx, args);
  //   const url = renderUrl(ctx, params);
  //
  //   return React.DOM.pre({}, React.DOM.a({
  //     href: url,
  //     target: 'blank'
  //   }, url));
  // });
  //
  // componentFn('img', 'Renders a graph image', ([ctx, ...args]) => {
  //   const params = argsToServerParams(ctx, args);
  //   const url = renderUrl(ctx, params);
  //   const deferred = Q.defer();
  //   const promise = deferred.promise.fail(function () {
  //     return Q.reject('Failed to load image');
  //   });
  //
  //   return AsyncComponent({
  //     promise: promise
  //   }, Builtins.ComponentAndError({
  //     promise: promise
  //   }, React.DOM.img({
  //     onLoad: deferred.resolve,
  //     onError: deferred.reject,
  //     src: url
  //   })), Builtins.PromiseStatusComponent({
  //     promise: promise,
  //     start_time: new Date()
  //   }));
  // });

  componentFn('browser', 'Browse metrics using a wildcard query', (ctx, query) => {
    const finder = Context.unwrapValue(contextExports.find.fn(ctx, query));

    finder.clicks.onValue((node) => {
      if (node.is_leaf) {
        return ctx.run(`q(${JSON.stringify(node.path)})`);
      } else {
        return ctx.run(`browser ${JSON.stringify(node.path + '.*')}`);
      }
    });

    return finder.component;
  });

  componentFn('tree', 'Generates a browsable tree of metrics', (ctx, root) => {
    return <MetricTreeComponent root={root}/>;
  });

  fn('find', 'Finds metrics', (ctx, query) => {
    const results = new Bacon.Model([]);

    const promise = find(ctx, query).then((r) => {
      results.set(r.result);
      return r;
    }).fail(() => {
      return Q.reject('Find request failed');
    });

    const clicks = new Bacon.Bus();
    const props = Bacon.Model.combine({
      results,
      query,
      onClick(node) {
        return clicks.push(node);
      }
    });

    const component = (
      <AsyncComponent promise={promise}>
        <Builtins.ComponentAndError promise={promise}>
          <Components.PropsModelComponent constructor={FindResultsComponent} child_props={props}/>
        </Builtins.ComponentAndError>
        <Builtins.PromiseStatusComponent promise={promise} start_time={new Date()}/>
      </AsyncComponent>
    );

    return Context.value({promise, clicks, component});
  });

  fn('get_data', 'Fetches metric data', (ctx, ...args) => {
    return Context.value(getData(ctx, argsToServerParams(ctx, args)));
  });

  fn('execute', 'Executes a DSL expression on the server', (ctx, ...args) => {
    return Context.value(execute(argsToServerParams(ctx, args)));
  });

  fn('batch', 'Executes a batch of DSL expressions with a promise for each', (ctx) => {
    return Context.value(batch(ctx, ctx.options()));
  });

  fn('executeOne', 'Executes a single DSL expression and returns a promise', (ctx, target, params) => {
    return Context.value(executeOne(ctx, target, params, ctx.options()));
  });

  return {
    init(ctx) {
      if (getSetting(ctx, 'type') === 'lead') {
        serverOptionNames = ['start', 'from', 'end', 'until', 'let'];

        if (!functionNames) {
          return http.get(ctx, url(ctx, 'functions')).fail(() => {
            functionNames = [];
            initDocs();
            return Q.reject('failed to load functions from lead server');
          }).then((functions) => {
            functionNames = Object.keys(functions).filter((f) => f.indexOf('-') === -1);
            contextExport(dsl.define_functions({}, functionNames));
            initDocs();
          });
        }
      } else {
        functionNames = GraphiteFunctionNames;
        contextExport(dsl.define_functions({}, functionNames));
        serverOptionNames = Object.keys(docs.parameter_docs);
        serverOptionNames.push('start', 'end');
        return initDocs();
      }
    }
  };
});

export {complete as suggest_strings};
