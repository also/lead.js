base_url = 'http://graphite.local'

_lead_finished = new Object

intro_text =
'''Welcome to lead.js!

Press Shift+Enter to execute the CoffeeScript in the console.'''

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

    if lead.is_lead_node last
      targets = args
      options = {}
    else
      [targets..., options] = args

  targets = [targets] unless $.isArray targets

  params = options
  params.target = (lead.to_string(target) for target in targets)
  params

scroll_to_result = ->
  setTimeout ->
    $('html, body').scrollTop $(document).height()
  , 10

create_ns = (context) ->
  cmd = (wrapped) ->
    wrapped._lead_cli_fn = wrapped
    wrapped

  fn = (wrapped) ->
    wrapped._lead_cli_fn = ->
      ns.pre 'Did you forget to call a function?'
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

  ns =
    object: fn output_object

    pre: fn (string) ->
      $pre = $ '<pre class="cm-string">'
      $pre.text string
      context.$result.append $pre
      context.success()

    intro: cmd -> ns.pre intro_text

    clear: cmd ->
      $output.empty()
      context.success()

    url: fn (args...) ->
      params = args_to_params args
      query_string = $.param params, true
      url = "#{base_url}/render?#{query_string}"
      $a = $ "<a href='#{url}' target='blank'/>"
      $a.text url
      $pre = $ '<pre>'
      $pre.append $a
      context.$result.append($pre)
      context.success()

    img: fn (args...) ->
      params = args_to_params args
      query_string = $.param params, true
      $img = $ "<img src='#{base_url}/render?#{query_string}'/>"
      $img.on 'load', -> context.success()
      context.$result.append($img)
      _lead_finished

    data: fn (args...) ->
      params = args_to_params args
      params.format = 'json'
      query_string = $.param params, true
      json "#{base_url}/render?#{query_string}"

    find: fn (query) ->
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
                  run "img q(#{JSON.stringify text})"
            $li.text text
            $ul.append $li
          context.$result.append $ul
          context.success()
      _lead_finished

    q: (targets...) ->
      _lead: ['q', _lead_to_string: -> targets.join ',']

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

  lead.define_functions ns, lead.functions

  `with (ns) {`
  result = eval "//@ sourceURL=console-coffeescript.js\n" +  CoffeeScript.compile(string, bare: true)
  unless result == _lead_finished
    if result?._lead_cli_fn
      result._lead_cli_fn()
    else if result?._lead
      ns.pre "What do you want to do with #{lead.to_string result}?"
    else
      ns.object result
  `}`

  $output.append $entry

run 'intro'
