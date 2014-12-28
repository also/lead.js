Q = require 'q'
_ = require 'underscore'
moment = require 'moment'
CodeMirror = require 'codemirror'
d3 = require('d3')

Context = require('./context')
colors = require './colors'
modules = require './modules'

requireables = {q: Q, _: _, moment, colors, d3}

modules.export exports, 'compat', ({doc, fn} ) ->
  fn 'require', (ctx, moduleName) ->
    Context.value(requireables[moduleName] ? ctx.modules[moduleName])

  context_vars:
    moment: moment
    CodeMirror: CodeMirror
