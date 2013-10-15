requirejs = require 'requirejs'

requirejs.config
  nodeRequire: require
  baseUrl: __dirname

requirejs.define 'cm/codemirror', {}
requirejs.define 'cm/runmode', {}
requirejs.define 'cm/javascript', {}
requirejs.define 'cm/coffeescript', {}
requirejs.define 'cm/show-hint', {}

exports.require = (k) ->
  exports[k] = requirejs k
