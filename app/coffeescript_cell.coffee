CoffeeScript = require 'coffee-script'
Editor = require './editor'
Context = require './context'
Builtins = require './builtins'
React = require 'react'
Components = require './components'
_ = require './core'
Javascript = require './javascript'

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

fnNumber = 1
# create the function for a string
# this is exposed for cases where there is no input cell
create_fn = (string) ->
  (ctx) ->
    try
      locals = Object.keys ctx.repl_vars
      compiled = CoffeeScript.compile(string, bare: true, locals: locals) + "\n//@ sourceURL=console-coffeescript-#{fnNumber++}.js"

      {global_vars, source} = Javascript.mangle compiled
      return Context.scoped_eval ctx, source, _.reject global_vars, (name) -> name.indexOf('_LEAD_COFFEESCRIPT_FREE_VARIABLE_') == 0
    catch e
      if e instanceof SyntaxError
        # TODO some errors hav loc instead of location: "Syntax Error: Unexpected character '…' (1:0)"
        if e.location?
          details = " at #{e.location.first_line + 1}:#{e.location.first_column + 1}"
        else
          details = ""
        Context.add_component ctx, Builtins.ErrorComponent message: "Syntax Error: #{e.message}#{details}"
      else
        _.logError('Exception in CoffeeScript cell', e)
        errorInfo = _.errorInfo(e)
        title = React.DOM.pre {}, errorInfo.message
        Context.add_component ctx, React.DOM.div {className: 'error'},
          if errorInfo.trace
            Components.ToggleComponent {title},
              React.DOM.pre {}, errorInfo.trace.join('\n')
          else
            title
          Components.ToggleComponent {title: 'Compiled JavaScript'},
            Components.SourceComponent language: 'javascript', value: compiled
     # this isn't a context fn, so it's value will be displayed
     Context.IGNORE

_.extend exports, {recompile, get_fn, create_fn}
