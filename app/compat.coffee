Q = require 'q'
_ = require 'underscore'
moment = require 'moment'
CodeMirror = require 'codemirror'

colors = require './colors'
modules = require './modules'

requireables = q: Q, _: _, moment: moment, colors: colors

modules.export exports, 'compat', ({doc, component_fn, cmd, fn} ) ->
  context_vars:
    moment: moment
    CodeMirror: CodeMirror
    require: (module_name) ->
      requireables[module_name] ? modules.get_module module_name
