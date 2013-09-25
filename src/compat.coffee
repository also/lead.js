define (require) ->
  Bacon = require 'baconjs'
  Q = require 'q'

  modules = require 'modules'
  graphite = require 'graphite'

  compat = modules.create 'compat', ({fn} ) ->
    fn 'graph', 'Graphs something', (args...) ->
      if Q.isPromise args[0]
        data = Bacon.fromPromise args[0]
        params = Bacon.combineTemplate args[1]
      else
        params = Bacon.constant graphite.args_to_params {args, default_options: @options()}
        data = params.map(graphite.get_data).flatMapLatest Bacon.fromPromise
      @graph.graph data, params
