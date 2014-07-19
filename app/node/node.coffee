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

exports.require = (m) ->
  require "./#{m}"

# TODO this is necessary to render react components into dom containers :(
enable_global_window()

global.is_nodejs = true
