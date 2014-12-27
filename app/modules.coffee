Q = require 'q'
_ = require 'underscore'
settings = require './settings'
Context = null

_.extend exports,
  export: (exports, module_name, definition_fn) ->
    module_settings = settings.with_prefix module_name
    context_fns = {}
    docs = []

    docs.push {key: module_name, doc: index: true}

    doc = (name, summary, complete) ->
      docs.push {key: [module_name, name], doc: {summary, complete}}

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
      context_fns[name] =
        module_name: module_name
        fn: f
        cmd_fn: cmd_f
        name: name

       return

    # TODO does this belong here?
    component_fn = optional_doc_fn (name, f) ->
      wrapped = (ctx) -> Context.add_component ctx, f.apply null, arguments
      wrapped.raw_fn = f
      fn name, wrapped

    component_cmd = optional_doc_fn (name, f) ->
      wrapped = (ctx) -> Context.add_component ctx, f.apply null, arguments
      wrapped.raw_fn = f
      cmd name, wrapped

    helpers = {doc, cmd, fn, component_cmd, component_fn, settings: module_settings}
    mod = _.extend {context_fns, docs}, definition_fn(helpers)

    _.extend exports, mod

  collect_extension_points: (modules, ep) ->
    _.flatten _.compact _.pluck modules, ep

  init_modules: (modules) ->
    Documentation = require './documentation'
    Context = require './context'

    promises = _.map modules, (mod, name) ->
      if mod.init?
        promise = Q(mod.init()).then -> mod
      else
        promise = Q(mod)
      promise.then (mod) ->
        if mod.docs?
          _.each mod.docs, ({key, doc}) ->
            Documentation.register_documentation key, doc

    Q.all(promises).then -> modules
