expect = require 'expect.js'
Server = require '../app/server'

describe 'server', ->
  it 'converts a single string to a single raw string target', ->
    {server} = Server.args_to_params args: ['test']
    expect(server.target.length).to.be 1
    expect(server.target[0]).to.be 'test'

  it 'accepts a named single target', ->
    {server} = Server.args_to_params args: [target: 'test']
    expect(server.target.length).to.be 1
    expect(server.target[0]).to.be 'test'

  it 'accepts an array of targets', ->
    {server} = Server.args_to_params args: [['test.1', 'test.2']]
    expect(server.target.length).to.be 2
    expect(server.target[0]).to.be 'test.1'
    expect(server.target[1]).to.be 'test.2'

  it 'accepts a named list of targets as target:', ->
    {server} = Server.args_to_params args: [target: ['test.1', 'test.2']]
    expect(server.target.length).to.be 2
    expect(server.target[0]).to.be 'test.1'
    expect(server.target[1]).to.be 'test.2'

  it 'accepts a named list of targets as targets:', ->
    {server} = Server.args_to_params args: [targets: ['test.1', 'test.2']]
    expect(server.target.length).to.be 2
    expect(server.target[0]).to.be 'test.1'
    expect(server.target[1]).to.be 'test.2'

  it 'accepts options as options:', ->
    {client, server} = Server.args_to_params args: [target: 'test', options: {yMax: 9999}]
    expect(server.target.length).to.be 1
    expect(server.target[0]).to.be 'test'
    expect(client.yMax).to.be 9999

  it 'treats everything except targets as options', ->
    {client, server} = Server.args_to_params args: [target: 'test', yMax: 9999]
    expect(server.target.length).to.be 1
    expect(server.target[0]).to.be 'test'
    expect(client.yMax).to.be 9999

  it 'accepts variadic string arguments as targets', ->
    {server} = Server.args_to_params args: ['a', 'b', 'c']
    expect(server.target.length).to.be 3
    expect(server.target[0]).to.be 'a'
    expect(server.target[1]).to.be 'b'
    expect(server.target[2]).to.be 'c'

  it "doesn't accept a single number", ->
    expect(-> Server.args_to_params args: [1]).to.throwException()

  it "doesn't accept a single object", ->
    expect(-> Server.args_to_params args: [{}]).to.throwException()

  xit "doesn't accept a single array", ->
    expect(-> Server.args_to_params args: [[]]).to.throwException()
