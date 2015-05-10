Q = require 'q'
_ = require 'underscore'
moment = require 'moment'
CodeMirror = require 'codemirror'
d3 = require('d3')

Context = require('./context')
colors = require './colors'
modules = require './modules'

requireables = {q: Q, _: _, moment, colors, d3}

modules.export exports, 'compat', ({doc, fn, contextExport} ) ->
  fn 'require', (ctx, moduleName) ->
    Context.value(requireables[moduleName] ? ctx.modules[moduleName])

  contextExport
    moment: moment
    CodeMirror: CodeMirror
    _: _
    ignore: Context.IGNORE
