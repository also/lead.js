colors = require './colors'
d3 = require 'd3'
_ = require 'underscore'
moment = require 'moment'
Q = require 'q'
Bacon = require 'bacon.model'
React = require 'react/addons'
modules = require './modules'
Documentation = require './documentation'
Server = require './server'
GraphDrawing = require './graph_drawing'
Context = require './context'
Builtins = require './builtins'
App = require './app'

ExportModal = React.createClass
  render: ->
    footer = React.DOM.button {onClick: @props.dismiss}, 'OK'
    App.ModalComponent {footer},
      React.DOM.img {src: @props.url, style: {border: '1px solid #aaa'}}

Graphing = modules.export exports, 'graphing', ({component_fn, doc, cmd, fn}) ->
  doc 'shareCursor', 'Use the same cursor on multiple graphs',
  '''
  # Usage

  ## `shareCursor()`

  Sets the `cursor` option to a new cursor. This cursor will be used by all subsequent calls to [`graph`](help:graphing.graph).

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

  Sets the `brush` option to a new brush. This brush will be used by all subsequent calls to [`graph`](help:graphing.graph).

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
    Context.value brushParams brush ? ctx.options().brush

  brushParams = (params, brush) ->
    brush.filter(({brushing}) -> !brushing).map ({extent}) ->
      if extent?
        start: moment(extent[0]).unix(), end: moment(extent[1]).unix()
      else
        start: params.start, end: params.end

  wrapModel = (model) ->
    if model?
      if model.get() instanceof Bacon.Observable
        model
      else
        new Bacon.Model model

  paramsToProperty = (params) ->
    if params.cursor? or params.brush?
      params = _.extend params, cursor: wrapModel(params.cursor), brush: wrapModel(params.brush)

    Bacon.combineTemplate params

  serverDataSource = (serverParams) ->
    new Server.LeadDataSource (params) ->
      Server.get_data _.extend {}, serverParams, params

  paramModifier = (newParams) ->
    (currentParams) ->
      result = _.extend {}, currentParams, newParams
      # Bacon checks for quality with ===, so don't change the value if possible
      if _.isEqual(currentParams, result)
        currentParams
      else
        result

  doc 'graph',
    'Loads and graphs time-series data'
    Documentation.load_file 'graphing.graph'

  component_fn 'graph', (ctx, args...) ->
    model = Graphing.createModel(ctx, args...)
    Graphing.GraphComponent {model}

  createModel: (ctx, args...) ->
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
      if args[0] instanceof Server.LeadDataSource
        source = args[0]
        # TODO opentsdb won't like some of these params
        params = _.extend {}, ctx.options(), args[1]
      else
        all_params = Server.args_to_params {args, default_options: ctx.options()}
        params = all_params.client
        source = serverDataSource(all_params.server)

      paramModifiers = []
      if params.bindToBrush == true
        params.brush ?= new Bacon.Model
        paramModifiers.push(brushParams(params, params.brush))
      else if params.bindToBrush instanceof Bacon.Observable
        params.brush ?= params.bindToBrush
        paramModifiers.push(brushParams(params, params.bindToBrush))
      if params.refreshInterval?
        paramModifiers.push(Bacon.interval(params.refreshInterval * 1000, {}).map(-> refreshTime: +new Date))

      if paramModifiers.length > 0
        paramsModel = new Bacon.Model(params)
        _.each paramModifiers, (observable) ->
          paramsModel.apply(observable.map(paramModifier))

        data = paramsModel.flatMapLatest (params) ->
          Bacon.fromPromise(source.load(params))
      else
        promise = source.load(params)

    if promise
      data = Bacon.fromPromise(promise)

    params = paramsToProperty(params)
    model = Bacon.Model({data: null, params: null, error: null})
    # TODO can these be combined?
    model.apply data.map (newData) -> ({params}) -> {params, data: newData, error: null}
    model.apply data.errors().mapError (newError) -> ({params}) -> {params, data: null, error: newError}
    model.lens('params').addSource(params)
    model

  GraphComponent: React.createClass
    displayName: 'GraphComponent'
    export: ->
      @state.graph.exportImage().then (url) ->
        App.pushModal handler: ExportModal, props: {url}
    render: ->
      React.DOM.div {},
        React.DOM.div {className: 'graph', ref: 'graph', style: {position: 'relative'}},
          if @state.error
            React.DOM.i {className: 'fa fa-exclamation-triangle', style: {position: 'absolute', fontSize: '30px', top: '50%', transform: 'translate(-50%,-50%)', left: '50%'}}
          React.DOM.span {className: 'fa-stack', title: 'Export', style: {position: 'absolute', top: '5px', right: '5px', cursor: 'pointer'}},
            React.DOM.i {className: 'fa fa-square fa-stack-2x', style: {color: '#fff'}}
            React.DOM.i
              onClick: @export
              className: 'fa fa-share-square-o fa-stack-1x'
              style: {color: '#ccc'}
        if @state.error
          Builtins.ErrorComponent {message: @state.error}
    componentWillReceiveProps: (nextProps) ->
      @state.unsubscribe()
      @subscribe(nextProps.model, @state.graph)
    getInitialState: -> {}
    componentDidMount: ->
      node = @refs.graph.getDOMNode()
      graph = GraphDrawing.create(node)
      @subscribe(@props.model, graph)
      @setState {graph}
    subscribe: (model, graph) ->
      @setState unsubscribe: model.onValue ({data, params, error}) =>
        @setState {error}
        graph.draw(data, params)
    componentWillUnmount: ->
      if @state.graph?
        @state.graph.destroy()
        @state.unsubscribe()

  DirectGraphComponent: React.createClass
    displayName: 'DirectGraphComponent'
    mixins: [React.addons.PureRenderMixin]
    getInitialState: ->
      graph: null
    componentDidMount: ->
      graph = GraphDrawing.create(@getDOMNode())
      graph.draw(@props.data, @props.params)
      @setState {graph}
    componentDidUpdate: ->
      @state.graph.draw(@props.data, @props.params)
    render: ->
      React.DOM.div {className: 'graph'}
