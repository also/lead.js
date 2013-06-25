define (require) ->
  CodeMirror = require 'cm/codemirror'
  marked = require 'lib/marked'
  lead = require 'core'
  graphite = require 'graphite'
  github = require 'github'
  graph = require 'graph'
  URI = require 'lib/URI'

  notebook = null
  require ['notebook'], (nb) ->
    notebook = nb

  ops = {}

  default_target_command = 'img'

  cmd = (name, doc, wrapped) ->
    result = wrapped
    result._lead_cli_fn = result

    fn name, doc, wrapped, wrapped

  fn = (name, doc, wrapped, cli_fn) ->
    result =
      fn: wrapped
      cli_fn: cli_fn ? ->
        @cli.text "Did you forget to call a function? \"#{result.name}\" must be called with arguments."
        @run "help #{result.name}"
      doc: doc
      name: name

    ops[name] = result

  args_to_params = (args, {default_options, current_options}) ->
    graphite.args_to_params {args, default_options: $.extend({}, default_options, current_options)}

  cmd 'help', 'Shows this help', (cmd) ->
    if cmd?
      cmd = cmd._lead_op?.name ? cmd
      doc = @ops[cmd]?.doc
      if doc
        @cli.pre "#{cmd}\n    #{doc}"
      else
        @cli.pre "#{cmd} is not a command."
    else
      cli_commands = (name for name, c of @ops when c.doc?)
      cli_commands.sort()
      $dl = $ '<dl>'
      for cmd in cli_commands
        $tt = $ '<tt/>'
        $tt.text cmd
        $dt = $ '<dt/>'
        $dt.append $tt
        $dl.append $dt
        $dd = $ '<dd/>'
        $dd.text @ops[cmd].doc
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
    @success()

  fn 'md', 'Renders Markdown', (string) ->
    $html = $ '<div class="user-html"/>'
    $html.html marked string
    @output $html

  fn 'text', 'Prints text', (string) ->
    $pre = $ '<p>'
    $pre.text string
    @output $pre
    @success()

  fn 'pre', 'Prints preformatted text', (string) ->
    $pre = $ '<pre>'
    $pre.text string
    @output $pre
    @success()

  fn 'html', 'Adds some HTML', (html) ->
    $html = $ '<div class="user-html"/>'
    $html.html html
    @output $html
    @success()

  fn 'error', 'Shows a preformatted error message', (message) ->
    $pre = $ '<pre class="error"/>'
    $pre.text message
    @output $pre
    @success()

  fn 'example', 'Makes a clickable code example', (string, opts) ->
    $pre = $ '<pre class="example">'
    CodeMirror.runMode string, 'coffeescript', $pre.get(0)
    $pre.on 'click', =>
      if opts?.run ? true
        @run string
      else
        @set_code string
    @output $pre
    @success()

  fn 'source', 'Shows source code with syntax highlighting', (language, string) ->
    $pre = $ '<pre>'
    CodeMirror.runMode string, 'javascript', $pre.get(0)
    @output $pre
    @success()

  cmd 'intro', 'Shows the intro message', ->
    @cli.text "Welcome to lead.js!\n\nPress Shift+Enter to execute the CoffeeScript in the console. Try running"
    @cli.example "find '*'"
    @cli.text 'Look at'
    @cli.example 'docs'
    @cli.text 'to see what you can do with Graphite.'

  cmd 'docs', 'Shows the documentation for a graphite function or parameter', (name) ->
    if name?
      name = name.to_js_string() if name.to_js_string?
      name = name._lead_op?.name if name._lead_op?
      dl = graphite.function_docs[name]
      if dl?
        $result = @output()
        pres = dl.getElementsByTagName 'pre'
        examples = []
        for pre in pres
          for line in pre.innerText.split '\n'
            if line.indexOf('&target=') == 0
              examples.push line[8..]
        $result.append dl.cloneNode true
        for example in examples
          @cli.example "#{default_target_command} #{JSON.stringify example}", run: false
      name = graphite.parameter_doc_ids[name] ? name
      div = graphite.parameter_docs[name]
      if div?
        $result = @output()
        docs = $(div.cloneNode true)
        context = @
        docs.find('a').on 'click', (e) ->
          e.preventDefault()
          href = $(this).attr 'href'
          if href[0] is '#'
            context.run "docs '#{decodeURI href[1..]}'"
        $result.append docs
      unless dl? or div?
        @cli.text 'Documentation not found'
      @success()
    else
      @cli.html '<h3>Functions</h3>'
      names = (name for name of graphite.function_docs)
      names.sort()
      for name in names
        sig = $(graphite.function_docs[name].getElementsByTagName('dt')[0]).text().trim()
        @cli.example "docs #{name}  # #{sig}"

      @cli.html '<h3>Parameters</h3>'
      names = (name for name of graphite.parameter_docs)
      names.sort()
      for name in names
        @cli.example "docs '#{name}'"
      @success()

  cmd 'clear', 'Clears the screen and code', ->
    @clear_output()
    @set_code ''
    @success()

  cmd 'quiet', 'Hides the input box', ->
    @hide_input()
    @success()

  fn 'options', 'Gets or sets options', (options) ->
    if options?
      $.extend @current_options, options
    @success()
    @value @current_options

  cmd 'defaults', 'Gets or sets default options', (options) ->
    if options?
      $.extend @default_options, options
    @success()
    @value @default_options

  fn 'params', 'Generates the parameters for a Graphite render call', (args...) ->
    result = args_to_params args, @
    @success()
    @value result

  fn 'url', 'Generates a URL for a Graphite image', (args...) ->
    params = args_to_params args, @
    url = graphite.render_url params
    $a = $ "<a href='#{url}' target='blank'/>"
    $a.text url
    $pre = $ '<pre>'
    $pre.append $a
    @output $pre
    @success()

  fn 'img', 'Renders a Graphite graph image', (args...) ->
    params = args_to_params args, @
    url = graphite.render_url params
    @async ->
      $img = $ "<img src='#{url}'/>"
      $img.on 'load', => @success()
      $img.on 'error', (args...) =>
        @cli.error 'Failed to load image'
        @failure()
      @output $img

  fn 'data', 'Fetches Graphite graph data', (args...) ->
    params = args_to_params args, @
    @async ->
      $result = @output()
      graphite.get_data params,
        success: (response) =>
          for series in response
            $header = $ '<h3>'
            $header.text series.target
            $result.append $header
            $table = $ '<table>'
            for [value, timestamp] in series.datapoints
              time = moment(timestamp * 1000)
              $table.append "<tr><th>#{time.format('MMMM Do YYYY, h:mm:ss a')}</th><td class='cm-number number'>#{value?.toFixed(3) or '(none)'}</td></tr>"
            $result.append $table
          @success()
        error: (error) =>
          @cli.error error
          @failure()

  fn 'graph', 'Graphs a Graphite target using d3', (args...) ->
    params = args_to_params args, @
    params.format = 'json'
    @async ->
      $result = @output()
      graphite.get_data params,
        success: (response) =>
          graph.draw $result.get(0), response, params
          @success()
        error: (error) =>
          @cli.error error
          @failure()

  fn 'find', 'Finds named Graphite metrics using a wildcard query', (query) ->
    query_parts = query.split '.'
    @async ->
      $result = @output()
      graphite.complete query,
        success: (response) =>
          $ul = $ '<ul class="find-results"/>'
          for node in response.metrics
            $li = $ '<li class="cm-string"/>'
            text = node.path
            text += '*' if node.is_leaf == '0'
            node_parts = text.split '.'
            for part, i in node_parts
              if i > 0
                $li.append '.'
              $span = $ '<span>'
              $span.addClass 'light' if part == query_parts[i]
              $span.text part
              $li.append $span
            do (text) =>
              $li.on 'click', =>
                if node.is_leaf == '0'
                  @run "find #{JSON.stringify text}"
                else
                  @run "q(#{JSON.stringify text})"
            $ul.append $li
          $result.append $ul
          @success()

  cmd 'permalink', 'Create a link to the code in the input cell above', (code) ->
    a = document.createElement 'a'
    a.href = location.href
    code ?= @previously_run()
    a.search = '?' + encodeURIComponent btoa code
    a.innerText = a.href
    @output a
    @success()

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
        $.ajax
          type: 'GET'
          url: url
          dataType: 'text'
          success: (response, status_text, xhr) =>
            @success()
            notebook.handle_file @,
              filename: URI(url).filename()
              type: xhr.getResponseHeader 'content-type'
              content: response
            , options
          error: (response, status_text, error) =>
            @cli.error status_text
            @failure()

  cmd 'gist', 'Loads a script from a gist', (gist, options={}) ->
    if arguments.length is 0
      @cli.save_gist()
    else
      url = github.to_gist_url gist
      @async ->
        @cli.text "Loading gist #{gist}"
        $.ajax
          type: 'GET'
          url: url
          dataType: 'json'
          success: (response) =>
            @success()
            for name, file of response.files
              notebook.handle_file @, file, options
          error: (response, status_text, error) =>
              @cli.error status_text
              @failure()

  cmd 'save_gist', 'Saves a notebook as a gist', ->
    notebook = @export_notebook()
    gist =
      public: true
      files:
        'notebook.lnb':
          content: JSON.stringify notebook
    @async ->
      github.save_gist gist,
        success: (result) =>
          @cli.html "<a href='#{result.html_url}'>#{result.html_url}</a>"
          lead_uri = URI window.location.href
          lead_uri.fragment "/#{result.html_url}"
          @cli.html "<a href='#{lead_uri}'>#{lead_uri}</a>"
          @success()
        error: =>
          @cli.error 'Save failed. Make sure your access token is configured correctly.'
          @failure()


  fn 'q', 'Escapes a Graphite metric query', (targets...) ->
    for t in targets
      unless $.type(t) is 'string'
        throw new TypeError "#{t} is not a string"
    @value new lead.type.q targets.map(String)...

  ops