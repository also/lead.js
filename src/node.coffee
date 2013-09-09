requirejs = require 'requirejs'

requirejs.config
  nodeRequire: require
  baseUrl: __dirname

exports.require = (k) ->
  exports[k] = requirejs k
