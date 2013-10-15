lead = require '../node'

# shim expect.js as expect
expect = require 'expect.js'
requirejs = require 'requirejs'
requirejs.define 'expect', -> expect

tests = lead.require 'test/runner'
tests.run()
