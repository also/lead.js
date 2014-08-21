Q = require 'q'
Documentation = require './documentation'
_ = require 'underscore'
settings = require './settings'
Context = require './context'

_.extend exports,
  export: (exports, module_name, definition_fn) ->
    _.extend exports, module.exports.create module_name, definition_fn
  create: (module_name, definition_fn) ->
    module_settings = settings.with_prefix module_name
    context_fns = {}

    Documentation.register_documentation module_name, index: true

    doc = (name, summary, complete) ->
      Documentation.register_documentation [module_name, name], {summary, complete}

    optional_doc_fn = (f) ->
      (args...) ->
        if _.isString args[1]
          [name, summary] = args
          doc name, summary
          args.splice 1, 1
        f args...

    cmd = optional_doc_fn (name, wrapped) ->
      fn name, wrapped, wrapped

    fn = optional_doc_fn (name, f, cmd_f) ->
      result =
        module_name: module_name
        fn: f
        cmd_fn: cmd_f
        name: name

      context_fns[name] = result

    # TODO does this belong here?
    component_fn = optional_doc_fn (name, f) ->
      wrapped = (ctx) -> Context.add_component ctx, f.apply null, arguments
      wrapped.raw_fn = f
      fn name, wrapped

    component_cmd = optional_doc_fn (name, f) ->
      wrapped = (ctx) -> Context.add_component ctx, f.apply null, arguments
      wrapped.raw_fn = f
      cmd name, wrapped

    mod = {doc, cmd, fn, component_cmd, component_fn, context_fns, settings: module_settings}
    if definition_fn?
      _.extend {context_fns, settings}, definition_fn mod
    else
      mod

  collect_extension_points: (modules, ep) ->
    _.flatten _.compact _.pluck modules, ep

  get_module: (module_name) ->
    require './' + module_name

  get_modules: (module_names) ->
    _.object module_names, _.map module_names, module.exports.get_module

  init_modules: (module_names) ->
    promises = _.map module_names, (name) ->
      mod = module.exports.get_module name
      if mod.init?
        Q(mod.init()).then -> mod
      else
        Q(mod)
    Q.all(promises).then (modules) ->
      _.object module_names, modules
