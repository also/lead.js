expect = require 'expect.js'
settings = require '../settings'

describe 'settings', ->
  s = null
  beforeEach ->
    s = settings.create()

  it 'can be set', ->
    s.set('a_setting', 'a_value').set('another_setting', 'another_value')

  it 'can be gotten', ->
    s.set 'a_setting', 'a_value'
    expect(s.get 'a_setting').to.be 'a_value'

    s.set '1', '2', 'a_setting', 'a_value'
    expect(s.get '1', '2', 'a_setting').to.be 'a_value'

  it 'can have defaults', ->
    s.default 'a_setting', 'a_value'
    expect(s.get 'a_setting').to.be 'a_value'
    s.default 'a_setting', 'another_value'
    expect(s.get 'a_setting').to.be 'a_value'

  it 'can be set using a prefix', ->
    s.with_prefix('a', 'b').set('a_setting', 'a_value')
    expect(s.get 'a', 'b', 'a_setting').to.be 'a_value'

  it 'can be gotten using a prefix', ->
    s.set('a', 'b', 'a_setting', 'a_value')
    expect(s.with_prefix('a', 'b').get('a_setting')).to.be 'a_value'
