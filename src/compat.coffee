define (require) ->
  Bacon = require 'baconjs'
  Q = require 'q'

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
      """

    fn 'graph', (args...) ->
      if Q.isPromise args[0]
        data_promise = args[0]
        params = Bacon.combineTemplate args[1]
      else
        graphite_params = graphite.args_to_params {args, default_options: @options()}
        params = Bacon.constant graphite_params
        data_promise = graphite.get_data graphite_params
      @graph.graph Bacon.fromPromise(data_promise), params
      @promise_status data_promise
