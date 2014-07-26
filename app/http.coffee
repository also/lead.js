$ = require 'jquery'
_ = require 'underscore'
Q = require 'q'
modules = require './modules'
Context = require './context'

http = modules.create 'http', ({fn}) ->
  fn 'execute', 'Executes an HTTP request', -> Context.value http.execute.apply http, arguments
  fn 'get', 'Executes an HTTP GET', -> Context.value http.get.apply http, arguments
  fn 'post', 'Executes an HTTP POST', -> Context.value http.post.apply http, arguments

  execute_xhr: (url, options) ->
    xhr = $.ajax _.extend {url, dataType: 'json', contentType: 'application/json'}, options
    Q.when(xhr).then -> Q.fulfill xhr
  execute: (url, options) -> Q.when $.ajax _.extend {url, dataType: 'json', contentType: 'application/json'}, options
  get: (url, options) -> http.execute url, _.extend {}, options, type: 'get'
  post: (url, data, options) -> http.execute url, _.extend {data: JSON.stringify data}, options, type: 'post'
  patch: (url, data, options) -> http.execute url, _.extend {data: JSON.stringify data}, options, type: 'patch'

module.exports = http
