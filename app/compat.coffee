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

  doc 'shareCursor', 'Use the same cursor on multiple graphs',
  '''
  # Usage

  ## `shareCursor()`

  Sets the `cursor` option to a new cursor. This cursor will be used by all subsequent calls to [`graph`](help:compat.graph).

  ## `shareCursor(false)`

  Unsets the `cursor` option.

  ## `shareCursor(cursor)`

  Sets the value of the `cursor` option to the specified cursor.
  '''

  cmd 'shareCursor', (ctx, share=true) ->
    options = ctx.options()
    if share == false
      delete options.cursor
    else
      if share instanceof Bacon.Observable
        options.cursor = share
      else
        options.cursor = new Bacon.Model

  doc 'shareBrush', 'Use the same brush on multiple graphs',
  '''
  # Usage

  ## `shareBrush()`

  Sets the `brush` option to a new brush. This brush will be used by all subsequent calls to [`graph`](help:compat.graph).

  ## `shareBrush(false)`

  Unsets the `brush` option.

  ## `shareBrush(brush)`

  Sets the value of the `brush` option to the specified brush.
  '''

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

  bindToBrush = (brush, source) ->
    serverParams = new Bacon.Model null
    serverParams.addSource compat.brushParams(brush)

    serverParams.flatMapLatest (brushParams) ->
      Bacon.fromPromise source.load brushParams

  fn 'bindToBrush', (ctx, args...) ->
    if args[0] instanceof Server.LeadDataSource
      source = args[0]
      brush = args[1]?.brush ? ctx.options().brush
    else
      allParams = Server.args_to_params {args, default_options: ctx.options()}
      source = new Server.LeadDataSource (brushParams) ->
        Server.get_data _.extend {}, allParams.server, brushParams
      brush = allParams.client.brush
    Context.value bindToBrush brush, source

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
    else if args[0] instanceof Server.LeadDataSource
      # TODO opentsdb won't like some of these params
      params = _.extend {}, ctx.options(), args[1]
      if params.bindToBrush == true
        params.brush ?= new Bacon.Model
        data = bindToBrush params.brush, args[0]
      else if params.bindToBrush instanceof Bacon.Observable
        data = bindToBrush params.bindToBrush, args[0]
      else
        promise = args[0].load params
    else
      all_params = Server.args_to_params {args, default_options: ctx.options()}
      params = all_params.client
      source = new Server.LeadDataSource (brushParams) ->
        Server.get_data _.extend {}, all_params.server, brushParams
      if params.bindToBrush == true
        params.brush ?= new Bacon.Model
        data = bindToBrush params.brush, source
      else if params.bindToBrush instanceof Bacon.Observable
        data = bindToBrush params.bindToBrush, source
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
