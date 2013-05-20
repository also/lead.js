base_url = 'http://grodan.biz'

_lead_finished = new Object

intro_text =

CodeMirror.keyMap.lead =
  Tab: (cm) ->
    if cm.somethingSelected()
      cm.indentSelection 'add'
    else
      spaces = Array(cm.getOption("indentUnit") + 1).join(" ")
      cm.replaceSelection(spaces, "end", "+input")
  'Shift-Enter': (cm) ->
    run cm.getValue()
  fallthrough: ['default']

$code = $ '#code'
$output = $ '#output'
#$code.height '100px'

editor = CodeMirror $code.get(0),
  mode: 'coffeescript'
  keyMap: 'lead'
  tabSize: 2
  autofocus: true
  viewportMargin: Infinity

$output.css 'padding-bottom': $code.height() + 'px'
editor.on 'viewportChange', ->
  $output.css 'padding-bottom': $code.height() + 'px'

args_to_params = (args) ->
  is_target = (x) ->
    $.type(x) == 'string' or lead.is_lead_node x

  if args.legnth == 0
    # you're doing it wrong
    {}
  if args.length == 1
    arg = args[0]
    if arg.targets
      targets = arg.targets
      if arg.options
        options = arg.options
      else
        options = arg
        delete options.targets
    else
      targets = args[0]
      options = {}
  else
    last = args[args.length - 1]

    if is_target last
      targets = args
      options = {}
    else
      [targets..., options] = args

  targets = [targets] unless $.isArray targets

  params = options
  params.target = (lead.to_target_string(target) for target in targets)
  params

scroll_to_result = ->
  setTimeout ->
    $('html, body').scrollTop $(document).height()
  , 10

create_ns = (context) ->
  cmd = (doc, wrapped) ->
    wrapped._lead_cli_fn = wrapped
    wrapped._lead_doc = doc
    wrapped

  fn = (doc, wrapped) ->
    wrapped._lead_cli_fn = ->
      cli.pre 'Did you forget to call a function?'
    wrapped._lead_doc = doc
    wrapped

  output_object = (o) ->
    $pre = $ '<pre>'
    CodeMirror.runMode JSON.stringify(o, null, '  '), {name: 'javascript', json: true}, $pre.get(0)
    context.$result.append $pre
    context.success()
    _lead_finished

  json = (url) ->
    $.ajax
      url: url
      dataType: 'json'
      success: (response) ->
        output_object response
    _lead_finished

  cli =
    help:
      cmd 'Shows this help', ->
        commands = ("  #{cmd}:\n    #{cli[cmd]._lead_doc}" for cmd in cli_commands).join('\n\n')
        cli.pre "Check out these awesome built-in functions:\n\n#{commands}"

    object:
      fn 'Prints an object as JSON', output_object

    pre:
      fn 'Prints a preformatted string', (string) ->
        $pre = $ '<pre class="cm-string">'
        $pre.text string
        context.$result.append $pre
        context.success()

    example:
      fn 'Makes a clickable code example', (string) ->
        $pre = $ '<pre class="example">'
        CodeMirror.runMode string, 'coffeescript', $pre.get(0)
        $pre.on 'click', ->
          run string
        context.$result.append $pre
        context.success()

    intro:
      cmd 'Shows the intro message', ->
        cli.pre "Welcome to lead.js!\n\nPress Shift+Enter to execute the CoffeeScript in the console. Try running"
        cli.example "find '*'"
        cli.pre 'Look at'
        cli.example 'lead.functions'
        cli.pre 'to see what you can do with Graphite.'

    clear:
      cmd 'Clears the screen', ->
        $output.empty()
        context.success()

    url:
      fn 'Generates a URL for a Graphite image', (args...) ->
        params = args_to_params args
        query_string = $.param params, true
        url = "#{base_url}/render?#{query_string}"
        $a = $ "<a href='#{url}' target='blank'/>"
        $a.text url
        $pre = $ '<pre>'
        $pre.append $a
        context.$result.append($pre)
        context.success()

    img:
      fn 'Renders a Graphite graph image', (args...) ->
        params = args_to_params args
        query_string = $.param params, true
        $img = $ "<img src='#{base_url}/render?#{query_string}'/>"
        $img.on 'load', -> context.success()
        context.$result.append($img)
        _lead_finished

    data:
      fn 'Fetches Graphite graph data', (args...) ->
        params = args_to_params args
        params.format = 'json'
        query_string = $.param params, true
        json "#{base_url}/render?#{query_string}"

    find:
      fn 'Finds named Graphite metrics using a wildcard query', (query) ->
        url = "#{base_url}/metrics/find?query=#{encodeURIComponent query}&format=completer"
        $.ajax
          url: url
          dataType: 'json'
          success: (response) ->
            $ul = $ '<ul class="find-results"/>'
            for node in response.metrics
              $li = $ '<li class="cm-string"/>'
              text = node.path
              text += '*' if node.is_leaf == '0'
              do (text) ->
                $li.on 'click', ->
                  if node.is_leaf == '0'
                    run "find #{JSON.stringify text}"
                  else
                    run "q(#{JSON.stringify text})"
              $li.text text
              $ul.append $li
            context.$result.append $ul
            context.success()
        _lead_finished

    q: do ->
      result = (targets...) ->
        _lead: ['q', _lead_to_string: -> targets.join ',']
      result._lead_doc = 'Escapes a Graphite metric query'
      result

  cli_commands = (k for k of cli)
  cli_commands.sort()

  cli

run = (string) ->
  $entry = $ '<div class="entry"/>'
  $input = $ '<pre class="input">'
  $input.on 'click', ->
    editor.setValue string
    editor.focus()
    editor.setCursor(line: editor.lineCount() - 1)

  $result = $ '<div class="result">'

  CodeMirror.runMode string, 'coffeescript', $input.get(0)

  $entry.append $input
  $entry.append $result
  context =
    $result: $result
    success: ->
      scroll_to_result()
      _lead_finished
    failure: ->
      scroll_to_result()
      _lead_finished

  ns = create_ns context
  functions = {}

  lead.define_functions functions, lead.functions

  `with (ns) { with (functions) {`
  result = eval "//@ sourceURL=console-coffeescript.js\n" +  CoffeeScript.compile(string, bare: true)
  unless result == _lead_finished
    if result?._lead_cli_fn
      result._lead_cli_fn()
    else if result?._lead
      lead_string = lead.to_string result
      ns.pre "What do you want to do with #{lead_string}?"
      safe_string = JSON.stringify lead_string
      for f in ['data', 'img', 'url']
        ns.example "#{f} #{safe_string}"
    else
      ns.object result
  `}}`

  $output.append $entry

run 'intro'
