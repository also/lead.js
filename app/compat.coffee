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

compat = modules.export exports, 'compat', ({doc, component_fn, cmd, fn} ) ->
  cmd 'shareCursor', (ctx, share=true) ->
    options = ctx.options()
    if share == false
      delete options.cursor
    else
      if share instanceof Bacon.Observable
        options.cursor = share
      else
        options.cursor = new Bacon.Model

  cmd 'shareBrush', (ctx, share=true) ->
    options = ctx.options()
    if share == false
      delete options.brush
    else
      if share instanceof Bacon.Observable
        options.brush = share
      else
        options.brush = new Bacon.Model

  fn 'brushParams', (ctx, brush) ->
    Context.value compat.brushParams brush ? ctx.options().brush

  bindToBrush = (brush, allParams) ->
    serverParams = new Bacon.Model allParams.server
    serverParams.addSource compat.brushParams(brush).map (brushParams) ->
      _.extend {}, allParams.server, brushParams

    serverParams.flatMapLatest (params) ->
      Bacon.fromPromise Server.get_data params

  fn 'bindToBrush', (ctx, args...) ->
    allParams = Server.args_to_params {args, default_options: ctx.options()}
    Context.value bindToBrush allParams.client.brush, allParams

  doc 'graph',
    'Loads and graphs time-series data'
    Documentation.load_file 'compat.graph'

  component_fn 'graph', (ctx, args...) ->
    if Q.isPromise args[0]
      promise = args[0]
      params = _.extend {}, ctx.options(), args[1]
    else if _.isArray(args[0]) and args[0][0]?.datapoints?
      data = Bacon.constant args[0]
      params = _.extend {}, ctx.options(), args[1]
    else if args[0] instanceof Bacon.Observable
      data = args[0]
      params = _.extend {}, ctx.options(), args[1]
    else
      all_params = Server.args_to_params {args, default_options: ctx.options()}
      params = all_params.client
      if params.bindToBrush == true
        params.brush ?= new Bacon.Model
        data = bindToBrush params.brush, all_params
      else if params.bindToBrush instanceof Bacon.Observable
        data = bindToBrush params.bindToBrush, all_params
        params.brush ?= params.bindToBrush
        delete params.bindToBrush
      else
        promise = Server.get_data all_params.server

    if promise
      data = Bacon.fromPromise(promise)
      Context.AsyncComponent {promise},
        React.DOM.div {style: {width: '-webkit-min-content'}},
          Builtins.ComponentAndError {promise},
            graph.create_component(data, params)
          Builtins.PromiseStatusComponent {promise, start_time: new Date}
    else
      # TODO async, error
      React.DOM.div {style: {width: '-webkit-min-content'}},
        graph.create_component(data, params)

  brushParams: (brush) ->
    brush.filter(({brushing}) -> !brushing).map ({extent}) ->
      if extent?
        start: moment(extent[0]).unix(), end: moment(extent[1]).unix()
      else
        {}

  context_vars:
    moment: moment
    CodeMirror: CodeMirror
    require: (module_name) ->
      requireables[module_name] ? modules.get_module module_name
