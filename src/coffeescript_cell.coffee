define (require) ->
  CoffeeScript = require 'coffee-script'
  Editor = require 'editor'
  Notebook = require 'notebook'
  Context = require 'context'

  recompile = (error_marks, editor) ->
    m.clear() for m in error_marks
    editor.clearGutter 'error'
    try
      CoffeeScript.compile editor.getValue()
      []
    catch e
      [Editor.add_error_mark editor, e]

  run = (run_context) ->
    string = run_context.input_cell.editor.getValue()
    Notebook.eval_coffeescript_into_output_cell run_context, string

  eval_coffeescript_in_context = (run_context, string) ->
    try
      compiled = CoffeeScript.compile(string, bare: true) + "\n//@ sourceURL=console-coffeescript.js"
      Context.eval_in_context run_context, compiled
    catch e
      if e instanceof SyntaxError
        run_context.error "Syntax Error: #{e.message} at #{e.location.first_line + 1}:#{e.location.first_column + 1}"
      else
        console.error e.stack
        run_context.error printStackTrace({e}).join('\n')
        run_context.text 'Compiled JavaScript:'
        run_context.source 'javascript', compiled

  {recompile, run, eval_coffeescript_in_context}
