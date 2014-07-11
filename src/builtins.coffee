define (require) ->
  CodeMirror = require 'cm/codemirror'
  require 'cm/runmode'
  URI = require 'URIjs'
  _ = require 'underscore'
  Markdown = require 'markdown'
  modules = require 'modules'
  http = require 'http'
  Documentation = require 'documentation'
  React = require 'react'
  Components = require 'components'

  Documentation.register_documentation 'introduction', complete: """
  # Welcome to lead.js

  Press <kbd>Shift</kbd><kbd>Enter</kbd> to execute the CoffeeScript in the console. Try running

  ```
  browser '*'
  ```

  Look at

  ```
  docs
  ```

  to see what you can do with Graphite.
  """

  ExampleComponent = Components.ExampleComponent

  get_fn_documentation = (fn) ->
    Documentation.get_documentation [fn.module_name, fn.name]

  fn_help_index = (ctx, fns) ->
    docs = _.map fns, (fn, name) ->
      if fn?
        doc = get_fn_documentation fn
        if doc?
          {name, doc}
    documented_fns = _.sortBy _.filter(docs, _.identity), 'name'
    Documentation.DocumentationIndexComponent entries: documented_fns, ctx: ctx

  Documentation.register_documentation 'imported_context_fns', complete: (ctx, doc) -> fn_help_index ctx, ctx.imported_context_fns

  modules.create 'builtins', ({doc, fn, cmd, component_fn, component_cmd}) ->
    help_component = (ctx, cmd) ->
      if _.isString cmd
        doc = Documentation.get_documentation cmd
        if doc?
          return Documentation.DocumentationItemComponent {ctx, name: cmd, doc}
        op = ctx.imported_context_fns[cmd]
        if op?
          doc = get_fn_documentation op
          if doc?
            return Documentation.DocumentationItemComponent {ctx, name: cmd, doc}
      else if cmd?._lead_context_name
        name = cmd._lead_context_name
        if cmd._lead_context_fn?
          doc = get_fn_documentation cmd._lead_context_fn
          return Documentation.DocumentationItemComponent {ctx, name, doc}
        else
          fns = _.object _.map cmd, (v, k) -> [k, v._lead_context_fn]
          return fn_help_index ctx, fns

      # TODO shouldn't be pre
      return PreComponent value: "Documentation for #{cmd} not found."

    component_cmd 'help', 'Shows this help', (cmd) ->
      if arguments.length > 0
        help_component @, cmd
      else
        help_component @, 'imported_context_fns'

    KeySequenceComponent = React.createClass
      displayName: 'KeySequenceComponent'
      render: -> React.DOM.span {}, _.map @props.keys, (k) -> React.DOM.kbd {}, k

    KeyBindingComponent = React.createClass
      displayName: 'KeyBindingComponent'
      render: ->
        React.DOM.table {}, _.map @props.keys, (command, key) =>
          React.DOM.tr {}, [
            React.DOM.th {}, KeySequenceComponent keys: key.split('-')
            React.DOM.td {}, React.DOM.strong {}, command.name
            React.DOM.td {}, command.doc
          ]

    component_cmd 'keys', 'Shows the key bindings', ->
      all_keys = {}
      # TODO some commands are functions instead of names
      build_map = (map) ->
        for key, command of map
          fn = CodeMirror.commands[command]
          unless key == 'fallthrough' or all_keys[key]? or not fn?
            all_keys[key] = name: command, doc: fn.doc
        fallthroughs = map.fallthrough
        if fallthroughs?
          build_map CodeMirror.keyMap[name] for name in fallthroughs
      build_map CodeMirror.keyMap.lead

      KeyBindingComponent keys: all_keys, commands: CodeMirror.commands

    fn 'In', 'Gets previous input', (n) ->
      @value @get_input_value n

    doc 'object',
      'Prints an object as JSON'
      """
      `object` converts an object to a string using `JSON.stringify` if possible and `new String` otherwise.
      The result is displayed using syntax highlighting.

      For example:

      ```
      object a: 1, b: 2, c: 3
      ```
      """

    component_fn 'object', (o) ->
      try
        s = JSON.stringify(o, null, '  ')
      catch
        s = null
      s ||= new String o
      Components.SourceComponent value: s, language: 'json'

    component_fn 'md', 'Renders Markdown', (string, opts) ->
      Markdown.MarkdownComponent value: string, opts: opts

    TextComponent = React.createClass
      displayName: 'TextComponent'
      render: -> React.DOM.p {}, @props.value

    PreComponent = React.createClass
      displayName: 'PreComponent'
      render: -> React.DOM.pre {}, @props.value

    HtmlComponent = React.createClass
      displayName: 'HtmlComponent'
      render: -> React.DOM.div className: 'user-html', dangerouslySetInnerHTML: __html: @props.value

    component_fn 'text', 'Prints text', (string) ->
      TextComponent value: string

    component_fn 'pre', 'Prints preformatted text', (string) ->
      PreComponent value: string

    component_fn 'html', 'Adds some HTML', (string) ->
      HtmlComponent value: string

    ErrorComponent = React.createClass
      displayName: 'ErrorComponent'
      render: -> React.DOM.pre {className: 'error'}, @props.message

    component_fn 'error', 'Shows a preformatted error message', (message) ->
      if not message?
        message = 'Unknown error'
        # TODO include stack trace?
      else if not _.isString message
        message = message.toString()
        # TODO handle exceptions better
      ErrorComponent {message}

    component_fn 'example', 'Makes a clickable code example', (value, opts) ->
      ExampleComponent ctx: @, value: value, run: opts?.run ? true

    component_fn 'source', 'Shows source code with syntax highlighting', (language, value) ->
      Components.SourceComponent {language, value}

    fn 'options', 'Gets or sets options', (options) ->
      if options?
        _.extend @current_options, options
      @value @current_options

    LinkComponent = React.createClass
      displayName: 'LinkComponent'
      render: -> React.DOM.a {href: @props.href}, @props.value

    component_cmd 'permalink', 'Create a link to the code in the input cell above', (code) ->
      uri = URI location.href
      uri.hash null
      code ?= @previously_run()
      uri.query '?' + encodeURIComponent btoa code
      uri = uri.toString()
      LinkComponent href: uri, value: uri

    PromiseStatusComponent = React.createClass
      displayName: 'PromiseStatusComponent'
      render: ->
        if @state?
          ms = @state.duration
          duration = if ms >= 1000
            s = (ms / 1000).toFixed 1
            "#{s} s"
          else
            "#{ms} ms"
          if @props.promise.isFulfilled()
            text = "Loaded in #{duration}"
          else
            text = "Failed after #{duration}"
        else
          text = "Loading"
        React.DOM.div {className: 'promise-status'}, text
      getInitialState: ->
        if @props.promise.isPending()
          null
        else
          return duration: 0
      finished: ->
        @setState duration: new Date - @props.start_time
      componentWillMount: ->
        # TODO this should probably happen earlier, in case the promise finishes before componentWillMount
        @props.promise.finally @finished

    component_fn 'promise_status', 'Displays the status of a promise', (promise, start_time=new Date) ->
      PromiseStatusComponent {promise, start_time}

    fn 'websocket', 'Runs commands from a web socket', (url) ->
      ws = new WebSocket url
      @async ->
        ws.onopen = => @text 'Connected'
        ws.onclose = =>
          @text 'Closed. Reconnect:'
          @example "websocket #{JSON.stringify url}"
        ws.onmessage = (e) => @run e.data
        ws.onerror = => @error 'Error'

    {ExampleComponent}
