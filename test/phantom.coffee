page = require("webpage").create()
page.onConsoleMessage = (msg) ->
  console.log msg

url = "http://localhost:8000/test/runner.html"
page.open url
page.onInitialized = ->
  page.evaluate ->
    window.mocha_callback = (failed) ->
      window.callPhantom failed

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
