define (require) ->
  Mocha = require 'mocha'
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
    m.run (failed) ->
      @mocha_callback? runner.failures

  run: ->
    require tests.map((t) -> "test/#{t}"), ->
      run_tests()

