requirejs = require 'requirejs'

requirejs.config
  nodeRequire: require
  baseUrl: __dirname

for k in ['dsl']
  exports[k] = requirejs k
