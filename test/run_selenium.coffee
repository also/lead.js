Q = require 'q'
_ = require 'underscore'
SauceTunnel = require 'sauce-tunnel'
wd = require 'wd'
expect = require 'expect.js'

username = process.env.SAUCE_USERNAME
access_key = process.env.SAUCE_ACCESS_KEY

start_tunnel = ->
  tunnel = new SauceTunnel username, access_key, null, true
  started = Q.defer()
  tunnel.start (status) ->
    if status == true
      started.resolve tunnel
    else
      started.reject status
  started.promise

run_with_tunnel = (fn) ->
  start_tunnel()
  .then (tunnel) ->
    driver_opts = host: 'ondemand.saucelabs.com', port: '80', username: username, accessKey: access_key
    init_opts = 'tunnel-identifier': tunnel.identifier
    # TODO the tunnel doesn't always stop
    Q(fn {driver_opts, init_opts}).finally -> tunnel.stop ->

run_in_browser = ({driver_opts, init_opts}, browser_opts, fn) ->
  browser = wd.promiseChainRemote driver_opts
  browser
    .init(_.extend {}, init_opts ? {}, browser_opts)
    .then(-> fn browser)
    .finally ->
      browser.quit()

run_in_browsers = (driver, browsers, fn) ->
  promises = _.map browsers, (browser) ->
    run_in_browser driver, browser, fn
  Q.allSettled(promises).then ->
    if _.every(promises, (p) -> p.isFulfilled())
      Q. resolve promises
    else
      Q.reject promises


run_tests = (browser) ->
  browser
    .setAsyncScriptTimeout(10000)
    .get("http://localhost:8000/test/runner.html?pause")
    .title().then (title) ->
      expect(title).to.be('lead.js test runner')
      browser.executeAsync('run(arguments[0])')
    .then (result) ->
      console.log result

run_remotely = ->
  run_with_tunnel (driver) ->
    run_in_browsers driver, [{browserName: 'chrome'}, {browserName: 'internet explorer'}], run_tests

run_locally = ->
  run_in_browser {}, {browserName: 'firefox'}, run_tests

#
#run_remotely().done()
#run_locally().done()
