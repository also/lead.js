page = require("webpage").create()
page.onConsoleMessage = (msg) ->
  console.log msg

page.onInitialized = ->
  page.injectJs 'lib/es5-shim-v2.2.0.js'

url = "http://localhost:8000/test/runner.html?pause"
page.open url, ->
  page.evaluate ->
    run (stats) ->
      window.callPhantom stats.failures

page.onResourceError = (error) ->
  console.log "tests failed to load: #{error.errorString}"
  phantom.exit 3

page.onCallback = (failed) ->
  if failed > 0
    console.log "#{failed} test(s) failed"
    phantom.exit 1
  else
    console.log 'all tests passed'
    phantom.exit 0

timeout = ->
  console.log "tests failed to complete"
  phantom.exit 2

setTimeout timeout, 10000
