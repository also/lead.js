require "!style!css!mocha/mocha.css"
document.write '<div id=mocha></div>'

runner = require './runner'

window.run = (callback) ->
  runner.run().then(callback).fail(callback)

# automated tests will load the page with ?pause and call run
if window.location.search != '?pause'
  run()
