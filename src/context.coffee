define (require) ->
  $ = require 'jquery'
  _ = require 'underscore'
  CoffeeScript = require 'coffee-script'
  printStackTrace = require 'stacktrace-js'
  modules = require 'modules'

  ignore = new Object

  running_context_binding = null

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
    if object?._lead_render
      @add_renderable object
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
        active_context = run_context.active_context()
        if @imported_context_fns? and @ != active_context
          # it looks like this is a context, but not the current one
          console.warn 'mismatched run context'
          console.trace()
        # if the function returned a value, unwrap it. otherwise, ignore it
        op.fn.apply(active_context, args)?._lead_context_fn_value ? ignore
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
    _.extend imported_context_fns, _.map(base.imports, (i) -> context_fns[i])...

    vars = collect_context_vars base
    imported_vars = _.extend {}, _.map(base.imports, (i) -> vars[i])...

    context = _.extend {}, base,
      context_fns: context_fns
      imported_context_fns: imported_context_fns
      vars: vars
      imported_vars: imported_vars

  create_run_context = (extra_contexts) ->
    result_handlers =[
      ignored,
      handle_cmd,
      handle_renderable,
      handle_using_extension
      handle_any_object
    ]

    delayed_renderable_list_builder = ($item) ->
      nested_renderables = []
      add_renderable: (renderable) -> nested_renderables.push renderable
      _lead_render: ->
        children = _.map nested_renderables, (i) -> i._lead_render()
        $item.append children
        $item

    run_context = _.extend {}, extra_contexts...,
      current_options: {}
      renderable_list_builder: delayed_renderable_list_builder $ '<div/>'
      _lead_render: -> run_context.current_context.renderable_list_builder._lead_render()
      active_context: ->
        console.warn 'no active running context. did you call an async function without keeping the context?' unless running_context_binding?
        run_context.current_context

      running_context: -> running_context_binding

      options: -> run_context.current_context.current_options

      in_context: (context, fn, args) ->
        previous_context = run_context.current_context
        run_context.current_context = context
        try
          fn.apply context, args
        finally
          run_context.current_context = previous_context

      in_running_context: (fn, args) ->
        throw new Error 'no active running context. did you call an async function without keeping the context?' unless running_context_binding?
        run_context.in_context running_context_binding, fn, args

      # returns a function that calls its argument in the current context
      capture_context: ->
        context = run_context.current_context
        running_context = running_context_binding
        (fn, args) ->
          previous_running_context_binding = running_context_binding
          running_context_binding = running_context
          try
            run_context.in_context context, fn, args
          finally
            running_context_binding = previous_running_context_binding

      # wraps a function so that it is called in the current context
      keeping_context: (fn) ->
        restoring_context = run_context.capture_context()
        ->
          restoring_context fn, arguments

      add_renderable: (renderable) ->
        run_context.current_context.renderable_list_builder.add_renderable renderable
        ignore

      add_rendered: (rendered) ->
        if rendered instanceof $
          run_context.add_rendering -> rendered.clone()
        else
          run_context.add_rendering -> rendered

      add_rendering: (rendering) -> run_context.add_renderable _lead_render: run_context.keeping_context(rendering)

      render: (o) -> o._lead_render()

      output: (output) ->
        $item = $ '<div class="item"/>'
        if output?
          $item.append output
        run_context.add_rendered $item
        $item

      renderable: (o, fn) ->
        o._lead_render = fn
        o

      nested: (className, fn, args...) ->
        $item = $ "<div class='#{className}'/>"
        run_context.current_context.nested_item $item, fn, args...

      create_nested_context: ($item) ->
        renderable = delayed_renderable_list_builder $item
        nested_context = _.extend {}, run_context,
          renderable_list_builder: renderable

      detached:  (fn, args) ->
        $item = $ "<div/>"
        nested_context = run_context.create_nested_context $item
        run_context.in_context nested_context, fn, args
        nested_context.renderable_list_builder

      nested_item: ($item, fn, args...) ->
        nested_context = run_context.create_nested_context $item
        run_context.add_renderable nested_context.renderable_list_builder
        run_context.in_context nested_context, fn, args

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

        promise = run_context.current_context.nested_item $item, fn
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

    run_context

  scope = (run_context) ->
    _.extend {}, run_context.fns, run_context.imported_vars

  create_standalone_context = ({imports, module_names}={}) ->
    create_base_context({imports: ['builtins'].concat(imports or []), module_names})
    .then (base_context) ->
      create_run_context [create_context base_context]

  eval_coffeescript_in_context = (run_context, string) ->
    try
      compiled = CoffeeScript.compile(string, bare: true) + "\n//@ sourceURL=console-coffeescript.js"
      eval_in_context run_context, compiled
    catch e
      if e instanceof SyntaxError
        run_context.error "Syntax Error: #{e.message} at #{e.location.first_line + 1}:#{e.location.first_column + 1}"
      else
        run_context.handle_exception e, compiled

  eval_in_context = (run_context, string) ->
    if _.isFunction string
      string = "(#{string}).apply(this);"
    run_in_context run_context, ->
      context_scope = scope run_context
      `with (context_scope) {`
      result = (-> eval string).call run_context
      `}`
      result

  run_in_context = (run_context, fn) ->
    try
      previous_running_context_binding = running_context_binding
      running_context_binding = run_context
      result = fn.apply run_context
      run_context.display_object result
    finally
      running_context_binding = previous_running_context_binding

  render = (o) ->
    o._lead_render()

  {
    create_base_context,
    create_context,
    create_run_context,
    create_standalone_context,
    run_in_context,
    eval_coffeescript_in_context,
    eval_in_context,
    render,
    scope,
    collect_extension_points
  }
