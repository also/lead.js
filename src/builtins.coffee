define (require) ->
  CodeMirror = require 'cm/codemirror'
  require 'cm/runmode'
  URI = require 'URIjs'
  $ = require 'jquery'
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

  help = (fns) ->
    documented_fns = (name for name, c of fns when c?.doc?)
    documented_fns.sort()
    $dl = $ '<dl/>'
    for cmd in documented_fns
      $tt = $ '<tt/>'
      $tt.text cmd
      $dt = $ '<dt/>'
      $dt.append $tt
      $dl.append $dt
      $dd = $ '<dd/>'
      $dd.text fns[cmd].doc
      $dl.append $dd
    $dl

  modules.create 'builtins', ({fn, cmd}) ->
    cmd 'help', 'Shows this help', (cmd) ->
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
          @pre "#{cmd} is not a command."
          return
      else
        fns = @imported_context_fns
      @add_rendered help(fns)

    cmd 'keys', 'Shows the key bindings', ->
      all_keys = {}
      build_map = (map) ->
        for key, command of map
          unless key == 'fallthrough' or all_keys[key]?
            all_keys[key] = command
        fallthroughs = map.fallthrough
        if fallthroughs?
          build_map CodeMirror.keyMap[name] for name in fallthroughs
      build_map CodeMirror.keyMap.lead

      $table = $ '<table/>'
      for key, command of all_keys
        fn = CodeMirror.commands[command]
        if fn
          doc = fn.doc ? ''
          kbd = key.split('-').map((k) -> "<kbd>#{k}</kbd>").join ' + '
          $table.append "<tr><th>#{kbd}</th><td><strong>#{command}</strong></td><td>#{doc}</td></tr>"
      @add_rendered $table

    fn 'In', 'Gets previous input', (n) ->
      @value @get_input_value n

    fn 'object', 'Prints an object as JSON', (o) ->
      try
        s = JSON.stringify(o, null, '  ')
      catch
        s = null
      s ||= new String o
      @add_component source value: s, language: 'json'

    fn 'md', 'Renders Markdown', (string) ->
      $html = $ '<div class="user-html"/>'
      $html.html marked string
      @add_rendered $html

    text = React.createClass
      render: -> React.DOM.p {}, @props.value

    pre = React.createClass
      render: -> React.DOM.pre {}, @props.value

    html = React.createClass
      render: -> React.DOM.div className: 'user-html', dangerouslySetInnerHTML: __html: @props.value

    fn 'text', 'Prints text', (string) ->
      @add_component text value: string

    fn 'pre', 'Prints preformatted text', (string) ->
      @add_component pre value: string

    fn 'html', 'Adds some HTML', (string) ->
      @add_component html value: string

    fn 'error', 'Shows a preformatted error message', (message) ->
      $pre = $ '<pre class="error"/>'
      $pre.text message
      @add_rendered $pre

    example = React.createClass
      render: -> React.DOM.div {className: 'example', onClick: @on_click}, @transferPropsTo source()
      on_click: ->
        if @props.run
          @props.ctx.run @props.value
        else
          @props.ctx.set_code @props.value

    fn 'example', 'Makes a clickable code example', (value, opts) ->
      @add_component example {ctx: @, value, run: opts?.run ? true, language: 'coffeescript'}

    source = React.createClass
      render: -> React.DOM.pre()
      componentDidMount: (node) -> format_code @props.value, @props.language, node

    fn 'source', 'Shows source code with syntax highlighting', (language, value) ->
      @add_component source {language, value}

    cmd 'intro', 'Shows the intro message', ->
      ctx = @
      @add_component React.createClass(
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

    cmd 'permalink', 'Create a link to the code in the input cell above', (code) ->
      a = document.createElement 'a'
      a.href = location.href
      a.hash = null
      code ?= @previously_run()
      a.search = '?' + encodeURIComponent btoa code
      a.innerText = a.href
      @add_rendered a

    fn 'websocket', 'Runs commands from a web socket', (url) ->
      ws = new WebSocket url
      @async ->
        ws.onopen = => @text 'Connected'
        ws.onclose = =>
          @text 'Closed. Reconnect:'
          @example "websocket #{JSON.stringify url}"
        ws.onmessage = (e) => @run e.data
        ws.onerror = => @error 'Error'
