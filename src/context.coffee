define (require) ->
  $ = require 'jquery'
  _ = require 'underscore'
  CoffeeScript = require 'coffee-script'
  printStackTrace = require 'stacktrace-js'
  modules = require 'modules'

  ignore = new Object

  # statement result handlers. return truthy if handled.
  ignored = (object) -> object == ignore

  handle_cmd = (object) ->
    if (op = object?._lead_context_fn)?
      if op.cmd_fn?
        op.cmd_fn.apply @
        true
      else
        @text "Did you forget to call a function? \"#{object._lead_context_name}\" must be called with arguments."
        @run "help #{object._lead_context_name}"
        true

  handle_renderable = (object) ->
    if fn = object?._lead_render
      fn.apply @
      true

  handle_using_extension = (object) ->
    handlers = collect_extension_points @, 'context_result_handler'
    context = @
    _.find handlers, (handler) -> handler.call context, object

  handle_any_object = (object) ->
    @object object
    true


  collect_extension_points = (context, extension_point) ->
    modules.collect_extension_points context.modules, extension_point

  collect_context_vars = (context) ->
    module_vars = (module, name) ->
      vars = module.context_vars
      if _.isFunction vars
        vars = vars.call context
      [name, vars]

    _.object _.filter _.map(context.modules, module_vars), ([n, f]) -> f

  collect_context_fns = (context) ->
    _.object _.filter _.map(context.modules, (module, name) -> [name, module.context_fns]), ([n, f]) -> f


  bind_context_fns = (run_context, fns, name_prefix='') ->
    bind_fn = (name, op) ->
      bound = (args...) ->
        # if the function returned a value, unwrap it. otherwise, ignore it
        op.fn.apply(run_context.root_context.current_context, args)?._lead_context_fn_value ? ignore
      bound._lead_context_fn = op
      bound._lead_context_name = name
      bound

    bound_fns = {}
    for k, o of fns
      if _.isFunction o.fn
        bound_fns[k] = bind_fn "#{name_prefix}#{k}", o
      else
        bound_fns[k] = _.extend {_lead_context_name: k}, bind_context_fns run_context, o, k + '.'

    bound_fns

  create_base_context = ({module_names, imports}) ->
    modules.load_modules(_.union imports or [], module_names or []).then (modules) ->
      {modules, imports}

  create_context = (base) ->
    context_fns = collect_context_fns base
    imported_context_fns = _.clone context_fns
    imported_context_fns._modules = context_fns
    _.extend imported_context_fns, _.map(base.imports, (i) -> context_fns[i])...

    vars = collect_context_vars base
    imported_vars = _.extend {}, _.map(base.imports, (i) -> vars[i])...

    context = _.extend {}, base,
      context_fns: context_fns
      imported_context_fns: imported_context_fns
      vars: vars
      imported_vars: imported_vars

  create_run_context = ($el, extra_contexts) ->
    result_handlers =[
      ignored,
      handle_cmd,
      handle_renderable,
      handle_using_extension
      handle_any_object
    ]

    output = ($target) ->
      (output) ->
        $target.removeClass 'clean'
        $item = $ '<div class="item"/>'
        if output?
          $item.append output
        $target.append $item
        $item

    run_context = _.extend {}, extra_contexts...,
      current_options: {}
      output: output $el

      options: -> @current_options

      in_context: (context, fn) ->
        previous_context = @root_context.current_context
        @root_context.current_context = context
        context_overridden = @root_context.context_overridden
        @root_context.context_overridden = true
        try
          fn()
        finally
          @root_context.current_context = previous_context
          @root_context.context_overridden = context_overridden

      render: (o) ->
        @nested 'renderable', handle_renderable, o
        # TODO warn if not renderable

      nested: (className, fn, args...) ->
        $item = $ "<div class='#{className}'/>"
        @nested_item $item, fn, args...

      nested_item: ($item, fn, args...) ->
        @output $item

        nested_context = _.extend {}, run_context,
          output: output $item
        nested_context.current_context = nested_context
        nested_context.fns = bind_context_fns nested_context, run_context.imported_context_fns
        fn.apply nested_context, args

      handle_exception: (e, compiled) ->
        console.error e.stack
        @error printStackTrace({e}).join('\n')
        @text 'Compiled JavaScript:'
        @source 'javascript', compiled

      display_object: (object) ->
        for handler in result_handlers
          return if handler.call run_context, object

      value: (value) -> _lead_context_fn_value: value

      async: (fn) ->
        $item = $ '<div class="async"/>'
        $item.attr 'data-async-status', 'loading'

        start_time = new Date

        duration = ->
          ms = new Date - start_time
          if ms >= 1000
            s = (ms / 1000).toFixed 1
            "#{s} s"
          else
            "#{ms} ms"

        promise = @nested_item $item, fn
        promise.then ->
          $item.attr 'data-async-status', "loaded in #{duration()}"
        promise.fail ->
          $item.attr 'data-async-status', "failed in #{duration()}"
        promise

    run_context.fns = bind_context_fns run_context, run_context.imported_context_fns
    fns_and_vars = bind_context_fns run_context, run_context.context_fns
    _.each run_context.vars, (vars, name) -> _.extend (fns_and_vars[name] ?= {}), vars
    _.extend fns_and_vars, fns_and_vars.builtins
    _.each fns_and_vars, (mod, name) ->
      if run_context[name]?
        console.warn mod._lead_context_name, 'would overwrite core'
      else
        run_context[name] = mod
    run_context.current_context = run_context
    run_context.root_context = run_context

    run_context

  scope = (run_context) ->
    _.extend {}, run_context.fns, run_context.imported_vars

  create_standalone_context = ($el, {imports, module_names}={}) ->
    create_base_context({imports: ['builtins'].concat(imports or []), module_names})
    .then (base_context) ->
      create_run_context $el, [create_context base_context]

  run_coffeescript_in_context = (run_context, string) ->
    try
      compiled = CoffeeScript.compile(string, bare: true) + "\n//@ sourceURL=console-coffeescript.js"
      run_in_context run_context, compiled
    catch e
      if e instanceof SyntaxError
        run_context.error "Syntax Error: #{e.message} at #{e.location.first_line + 1}:#{e.location.first_column + 1}"
      else
        run_context.handle_exception e, compiled

  run_in_context = (run_context, string) ->
    try
      context_scope = scope run_context
      `with (context_scope) {`
      result = eval string
      `}`
      run_context.display_object result
    catch e
      run_context.handle_exception e, string

  {create_base_context, create_context, create_run_context, create_standalone_context, run_coffeescript_in_context, run_in_context, scope, collect_extension_points}
