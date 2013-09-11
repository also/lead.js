define (require) ->
  CodeMirror = require 'cm/codemirror'
  require 'cm/runmode'
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
      $pre = $ '<pre>'
      s = JSON.stringify(o, null, '  ') or new String o
      CodeMirror.runMode s, {name: 'javascript', json: true}, $pre.get(0)
      @add_rendered $pre

    fn 'render', 'Renders an object', (o) ->
      @render o

    fn 'md', 'Renders Markdown', (string) ->
      $html = $ '<div class="user-html"/>'
      $html.html marked string
      @add_rendered $html

    fn 'text', 'Prints text', (string) ->
      $pre = $ '<p>'
      $pre.text string
      @add_rendered $pre

    fn 'pre', 'Prints preformatted text', (string) ->
      $pre = $ '<pre>'
      $pre.text string
      @add_rendered $pre

    fn 'html', 'Adds some HTML', (html) ->
      $html = $ '<div class="user-html"/>'
      $html.html html
      @add_rendered $html

    fn 'error', 'Shows a preformatted error message', (message) ->
      $pre = $ '<pre class="error"/>'
      $pre.text message
      @add_rendered $pre

    fn 'example', 'Makes a clickable code example', (string, opts) ->
      @add_rendering ->
        $pre = $ '<pre class="example">'
        CodeMirror.runMode string, 'coffeescript', $pre.get(0)
        $pre.on 'click', =>
          if opts?.run ? true
            @run string
          else
            @set_code string
        $pre

    fn 'source', 'Shows source code with syntax highlighting', (language, string) ->
      $pre = $ '<pre>'
      CodeMirror.runMode string, 'javascript', $pre.get(0)
      @add_rendered $pre

    cmd 'intro', 'Shows the intro message', ->
      @text "Welcome to lead.js!\n\nPress Shift+Enter to execute the CoffeeScript in the console. Try running"
      @example "browser '*'"
      @text 'Look at'
      @example 'docs'
      @text 'to see what you can do with Graphite.'

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
