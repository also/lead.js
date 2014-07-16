Mocha = require 'mocha'
Q = require 'q'
_ = require 'underscore'

m = mocha ? new Mocha
m.suite.emit 'pre-require', global, 'hack', m
tests = [
  'dsl'
  'settings'
  'context'
  'graphite'
  'github'
  'html'
]
# TODO
#if window?
#  tests.push 'notebook'

collect_suites = (suites) ->
  _.map suites, (suite) ->
    title: suite.title
    tests: collect_tests suite.tests
    suites: collect_suites suite.suites

collect_tests = (tests) ->
  _.map tests, (test) ->
    _.pick test, 'async', 'duration', 'pending', 'speed', 'state', 'sync', 'timedOut', 'title', 'type'

run_tests = ->
  deferred = Q.defer()
  runner = m.run (failed) ->
    result = _.extend {}, runner.stats, results: collect_suites runner.suite.suites
    if failed > 0
      deferred.reject result
    else
      deferred.resolve result
  deferred.promise

exports.run = ->
  _.each tests, (t) ->
    require './' + t
  run_tests()
