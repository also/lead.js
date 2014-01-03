define (require) ->
  Mocha = require 'mocha'
  Q = require 'q'

  m = mocha ? new Mocha
  m.suite.emit 'pre-require', global, 'hack', m
  tests = [
    'dsl'
    'settings'
    'context'
    'graphite'
    'github'
  ]
  # TODO
  if window?
    tests.push 'notebook'

  run_tests = ->
    result = Q.defer()
    runner = m.run (failed) ->
      if failed > 0
        result.reject runner.stats
      else
        result.resolve runner.stats
    result.promise

  run: ->
    result = Q.defer()
    require tests.map((t) -> "test/#{t}"), ->
      result.resolve run_tests()
    result.promise

