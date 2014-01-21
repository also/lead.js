define (require) ->
  Bacon = require 'baconjs'
  Q = require 'q'

  modules = require 'modules'
  graphite = require 'graphite'

  compat = modules.create 'compat', ({fn} ) ->
    fn 'graph', 'Graphs something', (args...) ->
      if Q.isPromise args[0]
        data_promise = args[0]
        params = Bacon.combineTemplate args[1]
      else
        graphite_params = graphite.args_to_params {args, default_options: @options()}
        params = Bacon.constant graphite_params
        data_promise = graphite.get_data graphite_params
      @graph.graph Bacon.fromPromise(data_promise), params
      @promise_status data_promise
