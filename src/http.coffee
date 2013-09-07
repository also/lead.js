define (require) ->
  $ = require 'jquery'
  _ = require 'underscore'
  Q = require 'q'
  modules = require 'modules'

  modules.create 'http', ({fn}) ->
    http =
      execute: (options) -> Q.when $.ajax options
      get: (url, options) -> http.execute _.extend {url, dataType: 'json'}, options, type: 'get'
      post: (url, data, options) -> http.execute _.extend {url, dataType: 'json', contentType: 'application/json', data: JSON.stringify data}, options, type: 'post'
  
    fn 'execute', 'Executes an HTTP request', http.execute
    fn 'get', 'Executes an HTTP GET', http.get
    fn 'post', 'Executes an HTTP POST', http.post

    http
