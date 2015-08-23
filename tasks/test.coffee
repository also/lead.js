Q = require 'q'
_ = require 'underscore'
selenium = require '../test/lib/selenium'
app_tests = require '../test/app_tests'

BUILD = process.env.TRAVIS_JOB_ID
APP_INFO = {
  name: 'app tests'
  build: BUILD
}

UNIT_INFO = {
  name: 'unit tests'
  build: BUILD
}
module.exports = (grunt) ->
  grunt.registerTask 'test-phantomjs', 'Runs the Mocha tests using PhantomJS', ->
    done = this.async()
    grunt.util.spawn cmd: 'phantomjs', args: ['build/node/test/phantom.js'], (err, result, code) ->
      if err?
        grunt.log.error 'Tests failed'
        grunt.log.error result.stdout
        done false
      else
        grunt.log.ok 'Tests passed'
        done()

  grunt.registerTask 'test-node', 'Runs the Mocha tests using node.js', ->
    done = @async()
    grunt.util.spawn cmd: 'node', args: ['build/node/test/run_node.js'], (err, result, code) ->
      if err?
        grunt.log.error 'Tests failed'
        grunt.log.error result.stdout
        grunt.log.error result.stderr
        done false
      else
        grunt.log.ok 'Tests passed'
        done()

  grunt.registerTask 'sauce-tunnel', 'Opens a Sauce Connect tunnel', ->
    done = @async()
    tunnel_started = (tunnel) ->
      grunt.log.ok 'Tunnel started: ' + tunnel.identifier
    tunnel_failed = (tunnel) ->
      grunt.log.error 'Failed to start tunnel'
      done false
    selenium.start_tunnel().then(tunnel_started, tunnel_failed).done()

  tests_passed = (results) ->
    grunt.log.ok 'Tests passed'
    true

  tests_failed = (results) ->
    grunt.log.error 'Tests failed'
    selenium.printSummary results
    false

  UNIT_TEST_BROWSERS = [{browserName: 'chrome'}, {browserName: 'firefox'}]
  REMOTE_UNIT_TEST_BROWSERS = [
    {browserName: "chrome", version: "31", platform: "OS X 10.9"}
    {browserName: 'internet explorer', version: '11', platform: 'Windows 8.1'}
    {browserName: 'chrome', version: '35', platform: 'Windows 8.1'}
    {browserName: 'firefox', version: '25', platform: 'Linux'}
  ]
  APP_TEST_BROWSERS = [{browserName: 'chrome'}]
  REMOTE_APP_TEST_BROWSERS = [{browserName: "chrome", version: "31", platform: "OS X 10.9"}]
  grunt.registerTask 'test-selenium-unit-remote', 'Runs the Mocha tests remotely using Selenium and Sauce Labs', ->
    done = @async()
    selenium
      .runRemotely(UNIT_INFO, REMOTE_UNIT_TEST_BROWSERS, selenium.unitTests)
      .then(tests_passed, tests_failed).then(done).done()

  grunt.registerTask 'test-selenium-unit-local', 'Runs the Mocha tests locally using Selenium', ->
    done = @async()
    selenium
      .runLocally(UNIT_TEST_BROWSERS, selenium.unitTests)
      .then(tests_passed, tests_failed).then(done).done()

  grunt.registerTask 'test-selenium-app-local', 'Runs the app tests locally using Selenium', ->
    done = @async()
    selenium
      .runLocally(APP_TEST_BROWSERS, app_tests)
      .then(tests_passed, tests_failed).then(done).done()

  grunt.registerTask 'test-selenium-app-remote', 'Runs the app tests remotely using Selenium and Sauce Labs', ->
    done = @async()
    selenium
      .runRemotely(APP_INFO, REMOTE_APP_TEST_BROWSERS, app_tests)
      .then(tests_passed, tests_failed).then(done).done()

  grunt.registerTask 'test-selenium-all-remote', 'Runs the unit and app tests remotely using Selenium and Sauce Labs', ->
    done = @async()
    selenium
      .run_with_tunnel (driver) ->
        app_results = selenium.runInSauceBrowsers driver, APP_INFO, REMOTE_APP_TEST_BROWSERS, app_tests
        unit_results = selenium.runInSauceBrowsers driver, UNIT_INFO, REMOTE_UNIT_TEST_BROWSERS, selenium.unitTests
        Q.allSettled([app_results, unit_results]).then -> [app_results, unit_results]
      .then(([app, unit]) ->
        Q.all([
          app.then(tests_passed, tests_failed)
          unit.then(tests_passed, tests_failed)
        ]).then((p) -> _.every p, (p) -> p)
      ).then(done).done()
