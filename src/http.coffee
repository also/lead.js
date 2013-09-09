define (require) ->
  $ = require 'jquery'
  _ = require 'underscore'
  Q = require 'q'
  modules = require 'modules'

  http = modules.create 'http', ({fn}) ->
    fn 'execute', 'Executes an HTTP request', -> @value http.execute.apply http, arguments
    fn 'get', 'Executes an HTTP GET', -> @value http.get.apply http, arguments
    fn 'post', 'Executes an HTTP POST', -> @value http.post.apply http, arguments

    execute: (options) -> Q.when $.ajax options
    get: (url, options) -> http.execute _.extend {url, dataType: 'json'}, options, type: 'get'
    post: (url, data, options) -> http.execute _.extend {url, dataType: 'json', contentType: 'application/json', data: JSON.stringify data}, options, type: 'post'
