define (require) ->
  CodeMirror = require 'cm/codemirror'
  require 'cm/runmode'
  URI = require 'URIjs'
  _ = require 'underscore'
  marked = require 'marked'
  modules = require 'modules'
  http = require 'http'
  React = require 'react'

  format_code = (code, language, target) ->
    target = target.get(0) if target.get?
    if CodeMirror.runMode?
      if language == 'json'
        opts = name: 'javascript', json: true
      else
        opts = name: language
      CodeMirror.runMode code, opts, target
    else
      target.textContent = code

  FunctionDocumentationComponent = React.createClass
    render: ->
      React.DOM.dl {}, _.map @props.fns, (fn) ->
        [
          React.DOM.dt {}, fn.name
          React.DOM.dd {}, fn.doc
        ]

  help = (fns) ->
    documented_fns = (name for name, c of fns when c?.doc?)
    documented_fns.sort()
    FunctionDocumentationComponent fns: _.map documented_fns, (name) -> {name, doc: fns[name].doc}

  modules.create 'builtins', ({fn, cmd}) ->
    component_cmd= (name, doc, f) ->
      cmd name, doc, -> @add_component f.apply @, arguments

    component_fn = (name, doc, f) ->
      fn name, doc, -> @add_component f.apply @, arguments

    component_cmd 'help', 'Shows this help', (cmd) ->
      if arguments.length > 0
        if _.isString cmd
          op = @imported_context_fns[cmd]
          fns = cmd: op if op?
        else if cmd?._lead_context_name
          name = cmd._lead_context_name
          if cmd._lead_context_fn?
            fns = {}
            fns[name] = cmd._lead_context_fn
          else
            fns = _.object _.map cmd, (v, k) -> [k, v._lead_context_fn]
        unless fns?
          return pre value: "#{cmd} is not a command."
      else
        fns = @imported_context_fns
      help fns

    KeyBindingComponent = React.createClass
      render: ->
        React.DOM.table {}, _.map @props.keys, (command, key) =>
          React.DOM.tr {}, [
            React.DOM.th {}, _.map key.split('-'), (k) -> React.DOM.kbd {}, k
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

    component_fn 'object', 'Prints an object as JSON', (o) ->
      try
        s = JSON.stringify(o, null, '  ')
      catch
        s = null
      s ||= new String o
      source value: s, language: 'json'

    MarkdownComponent = React.createClass
      render: -> React.DOM.div className: 'user-html', dangerouslySetInnerHTML: __html: marked @props.value

    component_fn 'md', 'Renders Markdown', (string) ->
      MarkdownComponent value: string

    text = React.createClass
      render: -> React.DOM.p {}, @props.value

    pre = React.createClass
      render: -> React.DOM.pre {}, @props.value

    html = React.createClass
      render: -> React.DOM.div className: 'user-html', dangerouslySetInnerHTML: __html: @props.value

    component_fn 'text', 'Prints text', (string) ->
      text value: string

    component_fn 'pre', 'Prints preformatted text', (string) ->
      pre value: string

    component_fn 'html', 'Adds some HTML', (string) ->
      html value: string

    ErrorComponent = React.createClass
      render: -> React.DOM.pre {className: 'error'}, @props.message

    component_fn 'error', 'Shows a preformatted error message', (message) ->
      ErrorComponent {message}

    example = React.createClass
      render: -> React.DOM.div {className: 'example', onClick: @on_click}, @transferPropsTo source()
      on_click: ->
        if @props.run
          @props.ctx.run @props.value
        else
          @props.ctx.set_code @props.value

    component_fn 'example', 'Makes a clickable code example', (value, opts) ->
      example {ctx: @, value, run: opts?.run ? true, language: 'coffeescript'}

    source = React.createClass
      render: -> React.DOM.pre()
      componentDidMount: (node) -> format_code @props.value, @props.language, node

    component_fn 'source', 'Shows source code with syntax highlighting', (language, value) ->
      source {language, value}

    component_cmd 'intro', 'Shows the intro message', ->
      ctx = @
      React.createClass(
        render: -> React.DOM.div {}, [
          text value: "Welcome to lead.js!\n\nPress Shift+Enter to execute the CoffeeScript in the console. Try running"
          example value: "browser '*'", ctx: ctx, run: true
          text value: 'Look at'
          example value: 'docs', ctx: ctx, run: true
          text value: 'to see what you can do with Graphite.'
        ])()

    fn 'options', 'Gets or sets options', (options) ->
      if options?
        _.extend @current_options, options
      @value @current_options

    LinkComponent = React.createClass
      render: -> React.DOM.a {href: @props.href}, @props.value

    component_cmd 'permalink', 'Create a link to the code in the input cell above', (code) ->
      a = document.createElement 'a'
      # TODO app should generate links
      a.href = location.href
      a.hash = null
      code ?= @previously_run()
      a.search = '?' + encodeURIComponent btoa code
      LinkComponent href: a.href, value: a.href

    fn 'websocket', 'Runs commands from a web socket', (url) ->
      ws = new WebSocket url
      @async ->
        ws.onopen = => @text 'Connected'
        ws.onclose = =>
          @text 'Closed. Reconnect:'
          @example "websocket #{JSON.stringify url}"
        ws.onmessage = (e) => @run e.data
        ws.onerror = => @error 'Error'
