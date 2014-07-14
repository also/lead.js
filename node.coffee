requirejs = require 'requirejs'

requirejs.config
  nodeRequire: require
  baseUrl: __dirname

jsdom = require("jsdom").jsdom

enable_global_window = ->
  unless global.window
    doc = jsdom("<html><body></body></html>")

    global.window = doc.parentWindow
    global.document = doc
    global.navigator = {userAgent: 'lol'}

exports.enable_codemirror = ->
  enable_global_window()
  require 'codemirror'
  CodeMirror = global.window.CodeMirror

  requirejs 'cm/codemirror'
  requirejs.undef 'cm/codemirror'
  requirejs.define 'cm/codemirror', -> CodeMirror

# TODO this is necessary to render react components into dom containers :(
enable_global_window()

requirejs.define 'cm/codemirror', {}
requirejs.define 'cm/runmode', {}
requirejs.define 'cm/javascript', {}
requirejs.define 'cm/coffeescript', {}
requirejs.define 'cm/show-hint', {}

requirejs.define 'html',
  parse_document: (html) -> jsdom html

exports.require = (k) ->
  exports[k] = requirejs k

global.is_nodejs = true
