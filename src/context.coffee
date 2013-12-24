define (require) ->
  $ = require 'jquery'
  _ = require 'underscore'
  CoffeeScript = require 'coffee-script'
  printStackTrace = require 'stacktrace-js'
  Bacon = require 'baconjs'
  React = require 'react'
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
        if @imported_context_fns? and @ != run_context.current_context
          # it looks like this is a context, but not the current one
          console.warn 'mismatched run context'
          console.trace()
        # if the function returned a value, unwrap it. otherwise, ignore it
        op.fn.apply(run_context.current_context, args)?._lead_context_fn_value ? ignore
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

  render = (o) ->
    o._lead_render()

  delayed_then_immediate_renderable_list_builder = ->
    $item = $ '<div/>'
    renderables = []
    rendered = false
    add_renderable: (renderable) ->
      if rendered
        $item.append render renderable
      else
        renderables.push renderable
    empty: ->
      renderables.length = 0
      $item.empty()
    _lead_render: ->
      unless rendered
        rendered = true
        children = _.map renderables, render
        $item.append children
      $item

  create_run_context = (extra_contexts) ->
    result_handlers =[
      ignored,
      handle_cmd,
      handle_renderable,
      handle_using_extension
      handle_any_object
    ]

    asyncs = new Bacon.Bus

    run_context_prototype = _.extend {}, extra_contexts...,
      changes: new Bacon.Bus
      pending: asyncs.scan 0, (a, b) -> a + b
      current_options: {}
      renderable_list_builder: delayed_then_immediate_renderable_list_builder()
      _lead_render: ->
        result = render @renderable_list_builder
        @changes.push true
        result

      running_context: -> running_context_binding

      options: -> @current_options

      apply_to: (fn, args) ->
        previous_context = scope_context.current_context
        scope_context.current_context = @
        try
          fn.apply @, args
        finally
          scope_context.current_context = previous_context

      in_running_context: (fn, args) ->
        throw new Error 'no active running context. did you call an async function without keeping the context?' unless running_context_binding?
        running_context_binding.apply_to fn, args

      # returns a function that calls its argument in the current context
      capture_context: ->
        context = @
        running_context = running_context_binding
        (fn, args) ->
          previous_running_context_binding = running_context_binding
          running_context_binding = running_context
          try
            context.apply_to fn, args
          finally
            running_context_binding = previous_running_context_binding

      # wraps a function so that it is called in the current context
      keeping_context: (fn) ->
        restoring_context = @capture_context()
        ->
          restoring_context fn, arguments

      add_renderable: (renderable) ->
        @renderable_list_builder.add_renderable renderable
        ignore

      add_component: (component) ->
        @add_rendering ->
          wrapper = document.createElement 'div'
          React.renderComponent component, wrapper
          wrapper

      add_rendered: (rendered) ->
        @add_rendering -> rendered

      # adds a function that can render
      add_rendering: (rendering) -> @add_renderable _lead_render: @keeping_context(rendering)

      render: render

      empty: -> @renderable_list_builder.empty()

      div: (contents) ->
        $div = $('<div/>')
        if contents?
          if _.isFunction contents
            return @nested_item contents
          else
            $div.append contents
        @add_rendered $div
        $div

      # makes o renderable using the given function or renderable
      renderable: (o, fn) ->
        if fn._lead_render?
          o._lead_render = fn._lead_render
        else
          nested_context = @create_nested_context
            renderable_list_builder: add_renderable: -> throw new Error 'Output functions not allowed inside a renderable'
          o._lead_render = -> nested_context.apply_to fn
        o

      create_nested_renderable_context: ($item) ->
        renderable = delayed_then_immediate_renderable_list_builder()
        @create_nested_context
          renderable_list_builder: renderable

      create_nested_context: (overrides) ->
        nested_context = _.extend create_new_run_context(@), overrides

      detached:  (fn, args) ->
        nested_context = @create_nested_renderable_context()
        nested_context.apply_to fn, args
        nested_context.renderable_list_builder

      # creates a nested context, adds it to the renderable list, and applies the function to it
      nested_item: (fn, args...) ->
        nested_context = @create_nested_renderable_context()
        @add_renderable nested_context.renderable_list_builder
        nested_context.apply_to fn, args

      display_object: (object) ->
        for handler in result_handlers
          return if handler.call @, object

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

        promise = @nested_item fn

        asyncs.push 1
        promise.finally =>
          asyncs.push -1
          @changes.push true
        promise.then ->
          $item.attr 'data-async-status', "loaded in #{duration()}"
        promise.fail ->
          $item.attr 'data-async-status', "failed in #{duration()}"
        promise

    scope_context = {}
    run_context_prototype.fns = bind_context_fns scope_context, run_context_prototype.imported_context_fns

    create_new_run_context = (parent) ->
      new_context = Object.create parent

      fns_and_vars = bind_context_fns new_context, new_context.context_fns
      _.each new_context.vars, (vars, name) -> _.extend (fns_and_vars[name] ?= {}), vars
      _.extend fns_and_vars, fns_and_vars.builtins
      _.each fns_and_vars, (mod, name) ->
        if run_context_prototype[name]?
          console.warn mod._lead_context_name, 'would overwrite core'
        else
          new_context[name] = mod
      new_context.current_context = new_context
      new_context
    run_context = scope_context.current_context = create_new_run_context run_context_prototype

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
        console.error e.stack
        run_context.error printStackTrace({e}).join('\n')
        run_context.text 'Compiled JavaScript:'
        run_context.source 'javascript', compiled


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
