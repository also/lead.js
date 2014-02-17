define (require) ->
  Bacon = require 'baconjs'
  Q = require 'q'
  _ = require 'underscore'

  modules = require 'modules'
  graphite = require 'graphite'

  compat = modules.create 'compat', ({fn, doc} ) ->
    doc 'graph',
      'Loads and graphs time-series data'
      """
      `graph` accepts a [Graphite target](help:graphite_functions) or promise of graph data.

      Graphite targets are converted to a promise using [`graphite.get_data`](help:graphite.get_data).

      For example:

      ```
      graph randomWalkFunction 'hello, world'
      ```

      # Data format
      The format for graph data is an array of time series:

      ```
      [
        {
          "target": "target name",
          "datapoints": [[value, timestamp], [value, timestamp], ...]
        }, ...
      ]
      ```

      For example:

      ```
      Q = require 'q'
      now = moment().unix()
      data = Q [
        {target: 'target 1', datapoints: [[1, now], [2, now + 60], [3, now + 120]]}
        {target: 'target 2', datapoints: [[0, now], [3, now + 60], [1, now + 120]]}
      ]

      graph data
      ```

      # Options

      ## [`areaMode`](help:graphite_parameters.areaMode)

      ```
      Q = require 'q'
      now = moment().unix()
      data = Q [
        {target: 'target 1', datapoints: [[1, now], [2, now + 60], [3, now + 120]]}
        {target: 'target 2', datapoints: [[0, now], [3, now + 60], [1, now + 120]]}
      ]

      options width: 400, height: 200
      graph data, areaMode: 'none'
      graph data, areaMode: 'first'
      graph data, areaMode: 'all'
      graph data, areaMode: 'stacked'
      ```

      ## `width` and `height`
      Set the width and height of the plot area. The legend is outside this area.

      ## `type`

      The type of graph to generate. `"line"` (the default) and `"scatter"` are supported.

      ```
      Q = require 'q'
      now = moment().unix()
      data = Q [
        {target: 'target 1', datapoints: [[1, now], [2, now + 60], [3, now + 120]]}
        {target: 'target 2', datapoints: [[0, now], [3, now + 60], [1, now + 120]]}
      ]

      options width: 400, height: 200
      graph data, type: 'line'
      graph data, type: 'scatter'
      ```

      ## `lineWidth`

      ```
      Q = require 'q'
      now = moment().unix()
      data = Q [
        {target: 'target 1', datapoints: [[1, now], [2, now + 60], [3, now + 120]]}
        {target: 'target 2', datapoints: [[0, now], [3, now + 60], [1, now + 120]]}
      ]

      options width: 400, height: 200
      graph data, lineWidth: 0.3
      graph data, lineWidth: 3
      graph data, lineWidth: 30
      ```

      ## `areaOffset`

      Used in conjuction with `areaMode`, `areaOffset` controls the baseline of the plot.
      This is used as the argument to the d3 [`offset` function](https://github.com/mbostock/d3/wiki/Stack-Layout#wiki-offset)
      and can be used to create "streamgraphs" or graphs that are normalized to fill the plot area.

      ```
      Q = require 'q'
      now = moment().unix()
      data = Q [
        {target: 'target 1', datapoints: [[1, now], [2, now + 60], [3, now + 120]]}
        {target: 'target 2', datapoints: [[0, now], [3, now + 60], [1, now + 120]]}
      ]

      options width: 400, height: 200
      graph data, areaMode: 'stacked', areaOffset: 'wiggle'
      graph data, areaMode: 'stacked', areaOffset: 'silhouette'
      graph data, areaMode: 'stacked', areaOffset: 'expand'
      ```

      ## `interpolate`

      ```
      Q = require 'q'
      now = moment().unix()
      data = Q [
        {target: 'target 1', datapoints: [[1, now], [2, now + 60], [3, now + 120]]}
        {target: 'target 2', datapoints: [[0, now], [3, now + 60], [1, now + 120]]}
      ]

      options width: 400, height: 200
      graph data, interpolate: 'basis'
      graph data, interpolate: 'cardinal'
      graph data, interpolate: 'basis'
      graph data, interpolate: 'step-before'
      graph data, interpolate: (points) -> points.join 'A 1,1 0 0 1 '
      md 'see http://bl.ocks.org/mbostock/3310323'
      ```

      ## `drawNullAsZero`

      ## `d3_colors`

      ## `yMin` and `yMax`

      ## `bgcolor`

      ## `get_value` and `get_timestamp`
      """

    fn 'graph', (args...) ->
      if Q.isPromise args[0]
        data_promise = args[0]
        params = Bacon.combineTemplate _.extend {}, @options(), args[1]
      else
        graphite_params = graphite.args_to_params {args, default_options: @options()}
        params = Bacon.constant graphite_params
        data_promise = graphite.get_data graphite_params
      @graph.graph Bacon.fromPromise(data_promise), params
      @promise_status data_promise
