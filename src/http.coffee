define (require) ->
  $ = require 'jquery'
  _ = require 'underscore'
  modules = require 'modules'

  {fn, cmd, context_fns} = modules.create()

  http =
    context_fns: context_fns
    execute: (options) -> $.ajax options
    get: (options) -> http.execute _.extend {}, options, type: 'get'
    getJSON: (options) -> http.execute _.extend {}, options, type: 'get', dataType: 'json'
    post: (options) -> http.execute _.extend {}, options, type: 'post'
  
  fn 'execute', 'Executes an HTTP request', http.execute
  fn 'get', 'Executes an HTTP GET', http.get
  fn 'getJSON', 'Executes an HTTP GET, returning parsed JSON', http.getJSON
  fn 'post', 'Executes an HTTP POST', http.post

  http
