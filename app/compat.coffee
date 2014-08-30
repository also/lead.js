Bacon = require 'baconjs'
Q = require 'q'
_ = require 'underscore'
moment = require 'moment'
CodeMirror = require 'codemirror'

React = require './react_abuse'
colors = require './colors'
modules = require './modules'
Server = require './server'
graph = require './graph'
Builtins = require './builtins'
Context = require './context'
Documentation = require './documentation'

requireables = q: Q, _: _, moment: moment, colors: colors

compat = modules.export exports, 'compat', ({doc, component_fn} ) ->
  doc 'graph',
    'Loads and graphs time-series data'
    Documentation.load_file 'compat.graph'

  component_fn 'graph', (ctx, args...) ->
    if Q.isPromise args[0]
      promise = args[0]
      params = Bacon.combineTemplate _.extend {}, ctx.options(), args[1]
    else
      server_params = Server.args_to_params {args, default_options: ctx.options()}
      params = Bacon.constant server_params
      promise = Server.get_data server_params

    data = Bacon.fromPromise(promise)
    Context.AsyncComponent {promise},
      React.DOM.div {style: {width: '-webkit-min-content'}},
        Builtins.ComponentAndError {promise},
          graph.create_component(data, params),
        Builtins.PromiseStatusComponent {promise, start_time: new Date}

  context_vars:
    moment: moment
    CodeMirror: CodeMirror
    require: (module_name) ->
      requireables[module_name] ? modules.get_module module_name
