define (require) ->
  CodeMirror = require 'cm/codemirror'
  URI = require 'URIjs'
  $ = require 'jquery'
  _ = require 'underscore'
  marked = require 'marked'
  modules = require 'modules'
  http = require 'http'

  help = (fns) ->
    documented_fns = (name for name, c of fns when c?.doc?)
    documented_fns.sort()
    $dl = $ '<dl>'
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
          op = @context_fns[cmd]
          fns = cmd: op if op?
        else if cmd?._lead_context_name
          name = cmd._lead_context_name
          if cmd._lead_context_fn?
            fns = {}
            fns[name] = cmd._lead_context_fn
          else
            fns = _.object _.map cmd, (v, k) -> [k, v._lead_context_fn]
        unless fns?
          @fns.pre "#{cmd} is not a command."
          return
      else
        fns = @context_fns
      @output help fns

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
      @output $table

    fn 'In', 'Gets previous input', (n) ->
      @value @get_input_value n

    fn 'object', 'Prints an object as JSON', (o) ->
      $pre = $ '<pre>'
      s = JSON.stringify(o, null, '  ') or new String o
      CodeMirror.runMode s, {name: 'javascript', json: true}, $pre.get(0)
      @output $pre

    fn 'render', 'Renders an object', (o) ->
      @render o

    fn 'md', 'Renders Markdown', (string) ->
      $html = $ '<div class="user-html"/>'
      $html.html marked string
      @output $html

    fn 'text', 'Prints text', (string) ->
      $pre = $ '<p>'
      $pre.text string
      @output $pre

    fn 'pre', 'Prints preformatted text', (string) ->
      $pre = $ '<pre>'
      $pre.text string
      @output $pre

    fn 'html', 'Adds some HTML', (html) ->
      $html = $ '<div class="user-html"/>'
      $html.html html
      @output $html

    fn 'error', 'Shows a preformatted error message', (message) ->
      $pre = $ '<pre class="error"/>'
      $pre.text message
      @output $pre

    fn 'example', 'Makes a clickable code example', (string, opts) ->
      $pre = $ '<pre class="example">'
      CodeMirror.runMode string, 'coffeescript', $pre.get(0)
      $pre.on 'click', =>
        if opts?.run ? true
          @run string
        else
          @set_code string
      @output $pre

    fn 'source', 'Shows source code with syntax highlighting', (language, string) ->
      $pre = $ '<pre>'
      CodeMirror.runMode string, 'javascript', $pre.get(0)
      @output $pre

    cmd 'intro', 'Shows the intro message', ->
      @fns.text "Welcome to lead.js!\n\nPress Shift+Enter to execute the CoffeeScript in the console. Try running"
      @fns.example "browser '*'"
      @fns.text 'Look at'
      @fns.example 'docs'
      @fns.text 'to see what you can do with Graphite.'

    fn 'options', 'Gets or sets options', (options) ->
      if options?
        _.extend @current_options, options
      @value @current_options

    cmd 'permalink', 'Create a link to the code in the input cell above', (code) ->
      a = document.createElement 'a'
      a.href = location.href
      code ?= @previously_run()
      a.search = '?' + encodeURIComponent btoa code
      a.innerText = a.href
      @output a

    fn 'websocket', 'Runs commands from a web socket', (url) ->
      ws = new WebSocket url
      @async ->
        ws.onopen = => @fns.text 'Connected'
        ws.onclose = =>
          @fns.text 'Closed. Reconnect:'
          @fns.example "websocket #{JSON.stringify url}"
        ws.onmessage = (e) => @run e.data
        ws.onerror = => @fns.error 'Error'
