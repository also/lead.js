define (require) ->
  _ = require 'underscore'

  create = ->
    data = {}

    get = (d, keys) ->
      return d if keys.length is 0
      return d unless d?
      [key, keys...] = keys
      get d[key], keys

    set = (d, value, keys) ->
      [key, keys...] = keys
      if keys.length is 0
        d[key] = value
      else
        set d[key] ?= {}, value, keys

    with_prefix = (prefix...) ->
      get: (keys...) ->
        get data, prefix.concat keys
      set: (keys..., value) ->
        set data, value, prefix.concat keys
        @

    settings = with_prefix()
    settings.with_prefix = with_prefix
    settings

  global_settings = create()
  global_settings.create = create
  global_settings
