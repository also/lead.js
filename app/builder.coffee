React = require 'react'
Bacon = require 'baconjs'
_ = require 'underscore'
Graphite = require './graphite'
Graph = require './graph'


exports.BuilderComponent = React.createClass
  displayName: 'BuilderComponent'
  getInitialState: ->
    leaf_clicks = new Bacon.Bus()
    targets = Bacon.Model([])
    targets.apply leaf_clicks.map (path) ->
      (targets) ->
        result = targets.slice()
        result.push path
        _.uniq result
        result
    render_results = targets.flatMapLatest (targets) ->
      if targets.length > 0
        Bacon.fromPromise Graphite.get_data {target: targets}
      else
        Bacon.once []
    data = Bacon.Model()
    data.addSource render_results
    params = Bacon.Model({})

    model: Bacon.Model.combine {data, params}
    leaf_clicks: leaf_clicks
  render: ->
    React.DOM.div {className: 'builder'},
      React.DOM.div {className: 'output tree'},
        Graphite.MetricTreeComponent
          root: @props.root
          leaf_clicked: (path) =>
            @state.leaf_clicks.push path
      React.DOM.div {className: 'output graph'},
        Graph.GraphComponent model: @state.model
