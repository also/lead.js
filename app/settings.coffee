_ = require 'underscore'
$ = require 'jquery'
Bacon = require 'baconjs'

init = ->
  Modules = require './modules'
  Context = require './context'
  Modules.export exports, 'settings', ({fn}) ->
    fn 'set', 'Sets a user setting', (ctx, keys..., value) ->
      user_settings.set keys..., value
    fn 'get', 'Gets a setting', (ctx, keys...) ->
      Context.value global_settings.get keys...

keysOverlap = (a, b) ->
  if a.length < b.length
    shorter = a
    longer = b
  else
    shorter = b
    longer = a
  _.isEqual longer.slice(0, shorter.length), shorter

create = (overrides=get:->) ->
  data = {}
  changeBus = new Bacon.Bus
  changeBus.plug overrides.changes if overrides.changes?

  get = (d, keys) ->
    return d if keys.length is 0
    return d unless d?
    [key, keys...] = keys
    get d[key], keys

  set = (d, value, keys) ->
    if keys.length == 0
      data = _.clone value
    [key, keys...] = keys
    if keys.length is 0
      d[key] = value
    else
      set d[key] ?= {}, value, keys

  with_prefix = (prefix...) ->
    get: (keys...) ->
      k = prefix.concat keys
      override = overrides.get k...
      value = get data, k
      unless override?
        value
      # TODO how does this handle arrays?
      else if _.isObject(override) and _.isObject(value)
        # TODO use lodash?
        $.extend true, {}, value, override
      else
        override

    get_without_overrides: (keys...) ->
      get data, prefix.concat keys

    set: (keys..., value) ->
      k = prefix.concat keys
      set data, value, k
      changeBus.push k
      @

    default: (keys..., value) ->
      @get(keys...) or @set keys..., value

    toProperty: (keys...) ->
      current = @get keys...
      k = prefix.concat keys
      changeBus.filter((changedKey) -> keysOverlap(k, changedKey)).map(=> _.clone(@get(keys...))).skipDuplicates(_.isEqual).toProperty(current)

    toModel: (keys...) ->
      current = @get(keys...)
      model = new Bacon.Model(current)
      model.addSource(@toProperty(keys...))
      model

  settings = with_prefix()
  # TODO is this necessary? i just want a normal EventStream that isn't pluggable or pushable
  settings.changes = changeBus.map _.identity
  settings.with_prefix = with_prefix
  settings

user_settings = create()

global_settings = create(user_settings)

_.extend exports, global_settings, {create, user_settings, init}
