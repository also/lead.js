expect = require 'expect.js'
graphite = require '../app/graphite'

describe 'graphite', ->
  it 'converts a single string to a single raw string target', ->
    params = graphite.args_to_params args: ['test']
    expect(params.target.length).to.be 1
    expect(params.target[0]).to.be 'test'

  it 'accepts a named single target', ->
    params = graphite.args_to_params args: [target: 'test']
    expect(params.target.length).to.be 1
    expect(params.target[0]).to.be 'test'

  it 'accepts an array of targets', ->
    params = graphite.args_to_params args: [['test.1', 'test.2']]
    expect(params.target.length).to.be 2
    expect(params.target[0]).to.be 'test.1'
    expect(params.target[1]).to.be 'test.2'

  it 'accepts a named list of targets as target:', ->
    params = graphite.args_to_params args: [target: ['test.1', 'test.2']]
    expect(params.target.length).to.be 2
    expect(params.target[0]).to.be 'test.1'
    expect(params.target[1]).to.be 'test.2'

  it 'accepts a named list of targets as targets:', ->
    params = graphite.args_to_params args: [targets: ['test.1', 'test.2']]
    expect(params.target.length).to.be 2
    expect(params.target[0]).to.be 'test.1'
    expect(params.target[1]).to.be 'test.2'

  it 'accepts options as options:', ->
    params = graphite.args_to_params args: [target: 'test', options: {yMax: 9999}]
    expect(params.target.length).to.be 1
    expect(params.target[0]).to.be 'test'
    expect(params.yMax).to.be 9999

  it 'treats everything except targets as options', ->
    params = graphite.args_to_params args: [target: 'test', yMax: 9999]
    expect(params.target.length).to.be 1
    expect(params.target[0]).to.be 'test'
    expect(params.yMax).to.be 9999

  it 'accepts variadic string arguments as targets', ->
    params = graphite.args_to_params args: ['a', 'b', 'c']
    expect(params.target.length).to.be 3
    expect(params.target[0]).to.be 'a'
    expect(params.target[1]).to.be 'b'
    expect(params.target[2]).to.be 'c'

  it "doesn't accept a single number", ->
    expect(-> graphite.args_to_params args: [1]).to.throwException()

  it "doesn't accept a single object", ->
    expect(-> graphite.args_to_params args: [{}]).to.throwException()

  xit "doesn't accept a single array", ->
    expect(-> graphite.args_to_params args: [[]]).to.throwException()
