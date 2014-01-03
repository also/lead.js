define (require) ->
  Mocha = require 'mocha'
  Q = require 'q'

  m = mocha ? new Mocha
  runner = null
  if @mocha_callback?
    m.reporter (r) ->
      runner = r
      new window.Mocha.reporters.HTML runner
  else
    runner = m.runner
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
    m.run (failed) ->
      if failed > 0
        result.reject runner
      else
        result.resolve runner
      @mocha_callback? runner.failures
    result.promise

  run: ->
    result = Q.defer()
    require tests.map((t) -> "test/#{t}"), ->
      result.resolve run_tests()
    result.promise

