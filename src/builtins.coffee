define (require) ->
  CodeMirror = require 'cm/codemirror'
  URI = require 'URIjs'
  $ = require 'jquery'
  marked = require 'lib/marked'
  lead = require 'core'
  modules = require 'modules'

  {fn, cmd, context_fns} = modules.create()
  cmd 'help', 'Shows this help', (cmd) ->
    if cmd?
      cmd = cmd._lead_context_fn?.name ? cmd
      doc = @context_fns[cmd]?.doc
      if doc
        @cli.pre "#{cmd}\n    #{doc}"
      else
        @cli.pre "#{cmd} is not a command."
    else
      cli_commands = (name for name, c of @context_fns when c.doc?)
      cli_commands.sort()
      $dl = $ '<dl>'
      for cmd in cli_commands
        $tt = $ '<tt/>'
        $tt.text cmd
        $dt = $ '<dt/>'
        $dt.append $tt
        $dl.append $dt
        $dd = $ '<dd/>'
        $dd.text @context_fns[cmd].doc
        $dl.append $dd
      @output $dl

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
    @cli.text "Welcome to lead.js!\n\nPress Shift+Enter to execute the CoffeeScript in the console. Try running"
    @cli.example "find '*'"
    @cli.text 'Look at'
    @cli.example 'docs'
    @cli.text 'to see what you can do with Graphite.'

  cmd 'clear', 'Clears the screen and code', ->
    @clear_output()
    @set_code ''

  cmd 'quiet', 'Hides the input box', ->
    @hide_input()

  fn 'options', 'Gets or sets options', (options) ->
    if options?
      _.extend @current_options, options
    @value @current_options

  cmd 'defaults', 'Gets or sets default options', (options) ->
    if options?
      _.extend @default_options, options
    @value @default_options

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
      ws.onopen = => @cli.text 'Connected'
      ws.onclose = =>
        @cli.text 'Closed. Reconnect:'
        @cli.example "websocket #{JSON.stringify url}"
      ws.onmessage = (e) => @run e.data
      ws.onerror = => @cli.error 'Error'

  cmd 'save', 'Saves the current notebook to a file', ->
    @save()

  cmd 'load', 'Loads a script from a URL', (url, options={}) ->
    if arguments.length is 0
      @open_file()
    else
      @async ->
        promise = $.ajax
          type: 'GET'
          url: url
          dataType: 'text'
        promise.done (response, status_text, xhr) =>
          notebook.handle_file @,
            filename: URI(url).filename()
            type: xhr.getResponseHeader 'content-type'
            content: response
          , options
        promise.fail (response, status_text, error) =>
          @cli.error status_text

  {context_fns}
