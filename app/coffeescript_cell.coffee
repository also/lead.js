CoffeeScript = require 'coffee-script'
Editor = require './editor'
Context = require './context'
Builtins = require './builtins'
React = require 'react'
Components = require './components'
printStackTrace = require 'stacktrace-js'
acorn = require 'acorn'
escope = require 'escope'
_ = require 'underscore'


if process.browser
  {Scope} = CoffeeScript.require './scope'
  freeVariable = Scope::freeVariable
  Scope::freeVariable = (name, reserve) -> freeVariable.call @, "LEAD_COFFEESCRIPT_FREE_VARIABLE_#{name}", reserve

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
      locals = Object.keys ctx.repl_vars
      compiled = CoffeeScript.compile(string, bare: true, locals: locals) + "\n//@ sourceURL=console-coffeescript.js"
      ast = acorn.parse compiled
      scopes = escope.analyze(ast).scopes
      global_scope = _.find scopes, (s) -> s.type == 'global'
      global_vars = _.pluck global_scope.variables, 'name'
      return Context.scoped_eval ctx, compiled, _.reject global_vars, (name) -> name.indexOf('_LEAD_COFFEESCRIPT_FREE_VARIABLE_') == 0
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
