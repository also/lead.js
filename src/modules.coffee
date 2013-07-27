define (require) ->
  settings = require 'settings'

  create: (name) ->
    if name?
      module_settings = settings.with_prefix name
    else
      module_settings = settings
    ops = {}

    cmd = (name, doc, wrapped) ->
      fn name, doc, wrapped, wrapped

    fn = (name, doc, wrapped, cli_fn) ->
      result =
        fn: wrapped
        cli_fn: cli_fn ? ->
          @cli.text "Did you forget to call a function? \"#{result.name}\" must be called with arguments."
          @run "help #{result.name}"
        doc: doc
        name: name

      ops[name] = result

    {cmd, fn, ops, settings: module_settings}
