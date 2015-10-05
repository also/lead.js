import $ from 'jquery';
import Q from 'q';
import * as Modules from './modules';
import * as Context from './context';


export function execute_xhr(ctx, url, options) {
  const xhr = $.ajax(Object.assign({
    url,
    dataType: 'json',
    contentType: 'application/json'
  }, options));

  return Q.when(xhr).then(() => Q.fulfill(xhr));
}

export let execute = function (ctx, url, options) {
  return Q.when($.ajax(Object.assign({url, dataType: 'json', contentType: 'application/json'}, options)));
};

export function setExecute(e) {
  execute = e;
}

export function get(ctx, url, options) {
  return execute(ctx, url, Object.assign({}, options, {type: 'get'}));
}

export function post(ctx, url, data, options) {
  return execute(ctx, url, Object.assign({data: JSON.stringify(data)}, options, {type: 'post'}));
}

export function patch(ctx, url, data, options) {
  return execute(ctx, url, Object.assign({data: JSON.stringify(data)}, options, {type: 'patch'}));
}

Modules.export(exports, 'http', function ({fn}) {
  fn('execute', 'Executes an HTTP request', (ctx, ...args) => {
    return Context.value(execute(ctx, ...args));
  });

  fn('get', 'Executes an HTTP GET', (ctx, ...args) => {
    return Context.value(get(ctx, ...args));
  });

  fn('post', 'Executes an HTTP POST', (ctx, ...args) => {
    return Context.value(post(ctx, ...args));
  });
});
