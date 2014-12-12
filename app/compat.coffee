Q = require 'q'
_ = require 'underscore'
moment = require 'moment'
CodeMirror = require 'codemirror'
d3 = require('d3')

colors = require './colors'
modules = require './modules'

requireables = {q: Q, _: _, moment, colors, d3}

modules.export exports, 'compat', ({doc, component_fn, cmd, fn} ) ->
  context_vars:
    moment: moment
    CodeMirror: CodeMirror
    require: (module_name) ->
      requireables[module_name] ? modules.get_module module_name
