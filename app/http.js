import $ from 'jquery';
import _ from 'underscore';
import Q from 'q';
import * as Modules from './modules';
import * as Context from './context';


export function execute_xhr(url, options) {
  const xhr = $.ajax(_.extend({
    url: url,
    dataType: 'json',
    contentType: 'application/json'
  }, options));

  return Q.when(xhr).then(function () {
    return Q.fulfill(xhr);
  });
}

export function execute(url, options) {
  return Q.when($.ajax(_.extend({
    url: url,
    dataType: 'json',
    contentType: 'application/json'
  }, options)));
}

export function get(url, options) {
  return execute(url, _.extend({}, options, {
    type: 'get'
  }));
}

export function post(url, data, options) {
  return execute(url, _.extend({
    data: JSON.stringify(data)
  }, options, {
    type: 'post'
  }));
}

export function patch(url, data, options) {
  return execute(url, _.extend({
    data: JSON.stringify(data)
  }, options, {
    type: 'patch'
  }));
}

Modules.export(exports, 'http', function ({fn}) {
  fn('execute', 'Executes an HTTP request', (ctx, ...args) => {
    return Context.value(execute(...args));
  });

  fn('get', 'Executes an HTTP GET', (ctx, ...args) => {
    return Context.value(get(...args));
  });

  return fn('post', 'Executes an HTTP POST', (ctx, ...args) => {
    return Context.value(post(...args));
  });
});
