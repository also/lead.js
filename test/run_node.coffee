lead = require '../node'

# shim expect.js as expect
expect = require 'expect.js'
requirejs = require 'requirejs'
# TODO improve build so this isn't necessary
requirejs.config
  paths:
    'graphite_docs': '../lib/graphite_docs'
requirejs.define 'expect', -> expect

tests = lead.require 'test/runner'
tests.run()
