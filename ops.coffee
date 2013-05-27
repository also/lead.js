lead.ops = {}

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

  lead.ops[name] = result

args_to_params = (args, {default_options, current_options}) ->
  lead.graphite.args_to_params {args, default_options: $.extend({}, default_options, current_options)}

cmd 'help', 'Shows this help', (cmd) ->
  if cmd?
    cmd = cmd._lead_op?.name ? cmd
    doc = lead.ops[cmd]?.doc
    if doc
      @cli.pre "#{cmd}\n    #{doc}"
    else
      @cli.pre "#{cmd} is not a command."
  else
    cli_commands = (name for name of lead.ops)
    cli_commands.sort()
    commands = ("  #{cmd}:\n    #{lead.ops[cmd].doc}" for cmd in cli_commands).join('\n\n')
    @cli.pre "Check out these awesome built-in functions:\n\n#{commands}"

fn 'object', 'Prints an object as JSON', (o) ->
  $pre = $ '<pre>'
  s = JSON.stringify(o, null, '  ') or new String o
  CodeMirror.runMode s, {name: 'javascript', json: true}, $pre.get(0)
  @$result.append $pre
  @success()
  lead._finished

fn 'text', 'Prints text', (string) ->
  $pre = $ '<p>'
  $pre.text string
  @$result.append $pre
  @success()

fn 'pre', 'Prints preformatted text', (string) ->
  $pre = $ '<pre>'
  $pre.text string
  @$result.append $pre
  @success()

fn 'html', 'Adds some HTML', (html) ->
  @$result.append html
  @success()

fn 'example', 'Makes a clickable code example', (string, opts) ->
  $pre = $ '<pre class="example">'
  CodeMirror.runMode string, 'coffeescript', $pre.get(0)
  $pre.on 'click', =>
    if opts?.run ? true
      @run string
    else
      @set_code string
  @$result.append $pre
  @success()

fn 'source', 'Shows source code with syntax highlighting', (language, string) ->
  $pre = $ '<pre>'
  CodeMirror.runMode string, 'javascript', $pre.get(0)
  @$result.append $pre
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
    dl = lead.graphite.function_docs[name]
    if dl?
      pres = dl.getElementsByTagName 'pre'
      examples = []
      for pre in pres
        for line in pre.innerText.split '\n'
          if line.indexOf('&target=') == 0
            examples.push line[8..]
      @$result.append dl.cloneNode true
      for example in examples
        @cli.example "#{default_target_command} #{JSON.stringify example}", run: false
    else
      name = lead.graphite.parameter_doc_ids[name] ? name
      div = lead.graphite.parameter_docs[name]
      if div?
        docs = $(div.cloneNode true)
        context = @
        docs.find('a').on 'click', (e) ->
          e.preventDefault()
          href = $(this).attr 'href'
          if href[0] is '#'
            context.run "docs '#{decodeURI href[1..]}'"
        @$result.append docs
      else
        @cli.text 'Documentation not found'
    @success()
  else
    @cli.html '<h3>Functions</h3>'
    names = (name for name of lead.graphite.function_docs)
    names.sort()
    for name in names
      sig = $(lead.graphite.function_docs[name].getElementsByTagName('dt')[0]).text().trim()
      @cli.example "docs #{name}  # #{sig}"

    @cli.html '<h3>Parameters</h3>'
    names = (name for name of lead.graphite.parameter_docs)
    names.sort()
    for name in names
      @cli.example "docs '#{name}'"
    @success()

cmd 'clear', 'Clears the screen and code', ->
  @clear_output()
  @set_code ''
  @success()

fn 'options', 'Gets or sets options', (options) ->
  if options?
    $.extend @current_options, options
  @success()
  @current_options

cmd 'defaults', 'Gets or sets default options', (options) ->
  if options?
    $.extend @default_options, options
  @success()
  @default_options

fn 'params', 'Generates the parameters for a Graphite render call', (args...) ->
  result = args_to_params args, @
  @success()
  result

fn 'url', 'Generates a URL for a Graphite image', (args...) ->
  params = args_to_params args, @
  url = lead.graphite.render_url params
  $a = $ "<a href='#{url}' target='blank'/>"
  $a.text url
  $pre = $ '<pre>'
  $pre.append $a
  @$result.append($pre)
  @success()

fn 'img', 'Renders a Graphite graph image', (args...) ->
  params = args_to_params args, @
  url = lead.graphite.render_url params
  $img = $ "<img src='#{url}'/>"
  $img.on 'load', => @success()
  $img.on 'error', (args...) =>
    @cli.text 'Failed to load image'
    @failure()
  @$result.append($img)
  lead._finished

fn 'data', 'Fetches Graphite graph data', (args...) ->
  params = args_to_params args, @
  lead.graphite.get_data params,
    success: (response) =>
      for series in response
        $header = $ '<h3>'
        $header.text series.target
        @$result.append $header
        $table = $ '<table>'
        for [value, timestamp] in series.datapoints
          time = moment(timestamp * 1000)
          $table.append "<tr><th>#{time.format('MMMM Do YYYY, h:mm:ss a')}</th><td class='cm-number number'>#{value?.toFixed(3) or '(none)'}</td></tr>"
        @$result.append $table
        @success()
  lead._finished

fn 'graph', 'Graphs a Graphite target using d3', (args...) ->
  params = args_to_params args, @
  params.format = 'json'
  lead.graphite.get_data params,
    success: (response) =>
      lead.graph.draw @$result.get(0), response, params
      @success()
  lead._finished

fn 'find', 'Finds named Graphite metrics using a wildcard query', (query) ->
  query_parts = query.split '.'
  lead.graphite.complete query,
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
      @$result.append $ul
      @success()
  lead._finished

cmd 'permalink', 'Create a link to the previously run statement', ->
  a = document.createElement 'a'
  a.href = location.href
  a.search = '?' + encodeURIComponent btoa @previously_run if @previously_run?
  a.innerText = a.href
  @$result.append a
  @success()

fn 'websocket', 'Runs commands from a web socket', (url) ->
  ws = new WebSocket url
  ws.onopen = => @cli.text 'Connected'
  ws.onclose = =>
    @cli.text 'Closed. Reconnect:'
    @cli.example "websocket #{JSON.stringify url}"
  ws.onmessage = (e) => @run e.data
  ws.onerror = => @cli.text 'Error'
  @success()

fn 'q', 'Escapes a Graphite metric query', (targets...) ->
  for t in targets
    unless $.type(t) is 'string'
      throw new TypeError "#{t} is not a string"
  new lead.type.q targets.map(String)...

