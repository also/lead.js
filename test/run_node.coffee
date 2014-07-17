lead = require '../app/node'

tests = require './runner'
tests.run()
.then ->
  process.exit 0
.fail ->
  process.exit 1
