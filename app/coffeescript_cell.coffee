CoffeeScript = require 'coffee-script'
Editor = require './editor'
Context = require './context'
Builtins = require './builtins'
React = require 'react'
Components = require './components'
printStackTrace = require 'stacktrace-js'

recompile = (error_marks, editor) ->
  m.clear() for m in error_marks
  editor.clearGutter 'error'
  try
    CoffeeScript.compile Editor.get_value editor
    []
  catch e
    [Editor.add_error_mark editor, e]

# gets the function for a cell
# TODO rename
get_fn = (run_context) ->
  create_fn Editor.get_value run_context.input_cell.editor

# create the function for a string
# this is exposed for cases where there is no input cell
create_fn = (string) ->
  (ctx) ->
    try
      compiled = CoffeeScript.compile(string, bare: true) + "\n//@ sourceURL=console-coffeescript.js"
      return Context.scoped_eval ctx, compiled
    catch e
      if e instanceof SyntaxError
        Context.add_component ctx, Builtins.ErrorComponent message: "Syntax Error: #{e.message} at #{e.location.first_line + 1}:#{e.location.first_column + 1}"
      else
        console.error e.stack
        Context.add_component ctx, React.DOM.div null,
          Builtins.ErrorComponent message: printStackTrace({e}).join('\n')
          'Compiled JavaScript:'
          Components.SourceComponent language: 'javascript', value: compiled
     # this isn't a context fn, so it's value will be displayed
     Context.IGNORE

module.exports = {recompile, get_fn, create_fn}
