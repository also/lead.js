define (require) ->
  settings = require 'settings'

  create: (module_name) ->
    if module_name?
      module_settings = settings.with_prefix module_name
    else
      module_settings = settings
    context_fns = {}

    cmd = (name, doc, wrapped) ->
      fn name, doc, wrapped, wrapped

    fn = (name, doc, fn, cmd_fn) ->
      result =
        module_name: module_name
        fn: fn
        cmd_fn: cmd_fn ? ->
          @fns.text "Did you forget to call a function? \"#{result.name}\" must be called with arguments."
          @run "help #{result.name}"
        doc: doc
        name: name

      context_fns[name] = result

    {cmd, fn, context_fns, settings: module_settings}

  collect_extension_points: (modules, ep) ->
    _.flatten _.compact _.pluck  modules, ep
