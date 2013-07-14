define (require) ->
  $ = require 'jquery'
  _ = require 'underscore'
  printStackTrace = require 'stacktrace-js'
  core = require 'core'

  ignore = new Object

  # statement result handlers. return truthy if handled.
  ignored = (object) -> object == ignore

  handle_cli_cmd = (object) ->
    if object?._lead_op?
      object._lead_op.cli_fn.apply @
      true

  handle_renderable = (object) ->
    if fn = object?._lead_render
      fn.apply @

  handle_lead_node = (object) ->
    if core.is_lead_node object
      lead_string = core.to_string object
      if _.isFunction object
        @cli.text "#{lead_string} is a Graphite function"
        @cli.example "docs #{object.values[0]}"
      else
        @cli.text "What do you want to do with #{lead_string}?"
        for f in ['data', 'graph', 'img', 'url']
          @cli.example "#{f} #{object.to_js_string()}"
      true

  handle_any_object = (object) ->
    @cli.object object
    true


  bind_cli = (run_context, ops) ->
    bind_op = (op) ->
      bound = (args...) ->
        # if the function returned a value, unwrap it. otherwise, ignore it
        op.fn.apply(run_context, args)?._lead_cli_value ? ignore
      bound._lead_op = op
      bound

    bound_ops = {}
    _.map ops, (op, k) ->
      bound = bind_op op
      Object.defineProperty bound_ops, k,
        get: -> bound
        set: -> throw new Error "#{k} is reserved"

    bound_ops

  create_run_context = ($el, opts={}) ->
    {extra_contexts, ops, function_names, vars} = _.defaults {}, opts,
      extra_contexts: []
      ops: {}
      function_names: []
      vars: {}

    scroll_to_top = ->
      setTimeout ->
        $('html, body').scrollTop $el.offset().top
      , 10

    result_handlers =[
      ignored,
      handle_cli_cmd,
      handle_renderable,
      handle_lead_node,
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

    run_context =
      ops: ops
      current_options: {}
      output: output $el
      scroll_to_top: scroll_to_top
      functions: core.define_functions {}, function_names
      vars: vars

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

        nested_context.cli = bind_cli nested_context, cli
        fn.apply nested_context, args

      handle_exception: (e, compiled) ->
        console.error e.stack
        @cli.error printStackTrace({e}).join('\n')
        @cli.text 'Compiled JavaScript:'
        @cli.source 'javascript', compiled

      error: (message) ->
        $pre = $ '<pre class="error"/>'
        $pre.text message
        run_context.output $pre

      display_object: (object) ->
        for handler in result_handlers
          return if handler.call run_context, object

      value: (value) -> _lead_cli_value: value

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
        promise.done ->
          $item.attr 'data-async-status', "loaded in #{duration()}"
          scroll_to_top()
        promise.fail ->
          $item.attr 'data-async-status', "failed in #{duration()}"
          scroll_to_top()

    run_context.cli = cli = bind_cli run_context, ops
    _.defaults run_context, extra_contexts...

    run_context

  {create_run_context}
