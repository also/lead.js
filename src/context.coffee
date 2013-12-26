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
    if is_renderable object
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

  render = (renderable) ->
    wrapper = document.createElement 'div'
    component = component_for_renderable renderable
    React.renderComponent component, wrapper
    $ wrapper

  is_component = (o) -> o?._lifeCycleState?

  is_renderable = (o) ->
    o? and (is_component(o) or o._lead_render?)

  renderable_component = React.createClass
    render: -> React.DOM.div()
    componentDidMount: (node) -> $(node).append @props.renderable._lead_render()

  component_list = React.createClass
    getInitialState: -> components: @components
    add_component: (c) ->
      @components ?= []
      @components.push c
      @setState components: @components if @state
    empty: ->
      @components = []
      @setState components: @components if @state
    render: ->
      React.DOM.div {}, @state.components

  component_for_renderable = (renderable) ->
    if is_component renderable
      renderable
    else if is_component renderable._lead_render
      renderable._lead_render
    # TODO remove context special case
    else if renderable.renderable_list_builder?
      renderable.renderable_list_builder
    else
      renderable_component {renderable}

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
      renderable_list_builder: component_list()
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
        @add_component component_for_renderable renderable
        ignore

      add_component: (component) ->
        @renderable_list_builder.add_component component

      add_rendered: (rendered) ->
        @add_rendering -> rendered

      # adds a function that can render.
      # the function will be called in the current context.
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
        if is_component fn
          o._lead_render = fn
        else if fn._lead_render?
          o._lead_render = fn._lead_render
        else
          nested_context = @create_nested_context
            renderable_list_builder: add_component: -> throw new Error 'Output functions not allowed inside a renderable'
          o._lead_render = -> nested_context.apply_to fn
        o

      create_nested_renderable_context: ->
        component = component_list()
        @create_nested_context
          renderable_list_builder: component

      create_nested_context: (overrides) ->
        nested_context = _.extend create_new_run_context(@), overrides

      detached:  (fn, args) ->
        nested_context = @create_nested_renderable_context()
        nested_context.apply_to fn, args
        nested_context.renderable_list_builder

      # creates a nested context, adds it to the renderable list, and applies the function to it
      nested_item: (fn, args...) ->
        nested_context = @create_nested_renderable_context()
        @add_component nested_context.renderable_list_builder
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
    render: (ctx) ->
      result = render ctx
      ctx.changes.push true
      result
    scope,
    collect_extension_points
  }
