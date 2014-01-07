Q = require 'q'
_ = require 'underscore'
request = require 'request'
SauceTunnel = require 'sauce-tunnel'
wd = require 'wd'
expect = require 'expect.js'

username = process.env.SAUCE_USERNAME
access_key = process.env.SAUCE_ACCESS_KEY
base_url =  "https://#{username}:#{access_key}@saucelabs.com/rest/v1/#{username}"

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

update_sauce_job = (job_id, details) ->
  Q.nfcall(
    request
    url: "#{base_url}/jobs/#{job_id}"
    method: 'put'
    body: details
    json: true
  )

run_in_browser = ({driver_opts, init_opts}, browser_opts, fn) ->
  browser = wd.promiseChainRemote driver_opts
  browser
    .init(_.extend {}, init_opts ? {}, browser_opts)
    .then ->
      browser.sessionCapabilities().then((c) ->browser.capabilities = c)
    .then(-> fn browser)
    .then(
      (result) -> {browser, result}
      (result) -> Q.reject {browser, result}
    )
    .finally ->
      browser.quit().fail ->

run_in_sauce_browsers = (driver, sauce_opts, browsers, fn) ->
  run_in_browsers driver, _.map(browsers, (b) ->_.extend({}, sauce_opts, b)), (browser) ->
    result = fn(browser)
    result.finally ->
      update_sauce_job browser.sessionID, passed: result.isFulfilled()

run_in_browsers = (driver, browsers, fn) ->
  promises = _.map browsers, (browser) ->
    run_in_browser driver, browser, fn
  Q.allSettled(promises).then ->
    if _.every(promises, (p) -> p.isFulfilled())
      Q. resolve promises
    else
      Q.reject promises

run_remotely = (sauce_opts, browsers, fn) ->
  run_with_tunnel (driver) ->
    run_in_sauce_browsers driver, sauce_opts, browsers, fn

run_locally = (browsers, fn) ->
  run_in_browsers {}, browsers, fn

print_summary = (results) ->
  _.map results, (r) ->
    snapshot = r.inspect()
    state = snapshot.state
    if state == 'fulfilled'
      value = snapshot.value
    else
      value = snapshot.reason
    {browser, result} = value
    {capabilities, defaultCapabilities} = browser
    unless capabilities?
      console.log '(failed creating browser)'
      capabilities = defaultCapabilities
    console.log "#{capabilities.browserName} #{capabilities.version} (#{capabilities.platform})"
    if state == 'fulfilled'
      console.log 'passed'
    else
      console.log 'failed'
      jsonwire_error = result['jsonwire-error']
      if jsonwire_error?
        console.log "#{jsonwire_error.status} #{jsonwire_error.summary}: #{jsonwire_error.detail}"
      else
        console.log "unknown error:"
        if result.stack
          console.log result.stack
        else
          console.log result.toString()
        console.log JSON.stringify result
    console.log()

unit_tests = (browser) ->
  browser
    .setAsyncScriptTimeout(10000)
    .get("http://localhost:8000/test/runner.html?pause")
    .title().then (title) ->
      expect(title).to.be('lead.js test runner')
      browser.executeAsync('run(arguments[0])')

module.exports = {
  start_tunnel
  run_locally
  run_remotely
  run_with_tunnel
  run_in_browsers
  unit_tests
  print_summary
  update_sauce_job
  run_in_sauce_browsers
}
