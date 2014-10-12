colors = require './colors'
d3 = require 'd3'
_ = require 'underscore'
moment = require 'moment'
Q = require 'q'
Bacon = require 'bacon.model'
React = require './react_abuse'
modules = require './modules'
GraphDrawing = require './graph_drawing'

Graph = modules.export exports, 'graph', ({component_fn}) ->
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

  component_fn 'graph', 'Graphs time series data using d3', (ctx, data, params={}) ->
    Graph.create_component data, params

  create_component: (data, params) ->
    data = Bacon.fromPromise data if Q.isPromise data
    params = paramsToProperty params
    stream = Bacon.combineTemplate {data, params}
    model = Bacon.Model()
    model.addSource stream
    # TODO seems like the combined stream doesn't error?
    # TODO error handling
    Graph.GraphComponent {model}

  GraphComponent: React.createClass
    displayName: 'GraphComponent'
    render: ->
      React.DOM.div {className: 'graph'}
    componentDidMount: ->
      node = @getDOMNode()
      graph = GraphDrawing.create(node)
      # FIXME #175 props can change
      unsubscribe = @props.model.onValue ({data, params}) =>
        return unless data?
        graph.draw(data, params)
      @setState {graph, unsubscribe}
    componentWillUnmount: ->
      if @state
        @state.graph.destroy()
        @state.unsubscribe()


