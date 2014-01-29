define (require) ->
  Q = require 'q'
  Documentation = require 'documentation'
  _ = require 'underscore'
  settings = require 'settings'

  create: (module_name, definition_fn) ->
    module_settings = settings.with_prefix module_name
    context_fns = {}

    cmd = (name, doc, wrapped) ->
      fn name, doc, wrapped, wrapped

    fn = (name, doc, fn, cmd_fn) ->
      Documentation.register_documentation [module_name, name], summary: doc
      result =
        module_name: module_name
        fn: fn
        cmd_fn: cmd_fn
        name: name

      context_fns[name] = result

    # TODO does this belong here?
    component_fn = (name, doc, f) ->
      fn name, doc, -> @add_component f.apply @, arguments

    component_cmd= (name, doc, f) ->
      cmd name, doc, -> @add_component f.apply @, arguments

    mod = {cmd, fn, component_cmd, component_fn, context_fns, settings: module_settings}
    if definition_fn?
      _.extend {context_fns, settings}, definition_fn mod
    else
      mod

  collect_extension_points: (modules, ep) ->
    _.flatten _.compact _.pluck modules, ep

  load_modules: (module_names) ->
    if module_names.length > 0
      loaded = Q.defer()
      require module_names, (imported_modules...) ->
        loaded.resolve _.object module_names, imported_modules
      , (err) ->
        loaded.reject err
      loaded.promise.then (imported_modules) ->
        inits = Q.all _.compact _.map imported_modules, (module) ->  module.init?()
        inits.then -> imported_modules
    else
      Q {}
