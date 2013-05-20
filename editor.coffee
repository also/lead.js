base_url = 'http://graphite.local'
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
  $('html, body').scrollTop $(document).height()

create_ns = (context) ->
  json = (url) ->
    $.ajax
      url: url
      dataType: 'json'
      success: (response) ->
        $pre = $ '<pre class="cm-s-default">'
        CodeMirror.runMode JSON.stringify(response, null, '  '), {name: 'javascript', json: true}, $pre.get(0)
        context.$result.append $pre
        context.success()

  clear: ->
    $output.empty()
    context.success()

  url: (args...) ->
    params = args_to_params args
    query_string = $.param params, true
    url = "#{base_url}/render?#{query_string}"
    $a = $ "<a href='#{url}' target='blank'/>"
    console.log $a
    $a.text url
    $pre = $ '<pre>'
    $pre.append $a
    context.$result.append($pre)
    context.success()

  img: (args...) ->
    params = args_to_params args
    query_string = $.param params, true
    $img = $ "<img src='#{base_url}/render?#{query_string}'/>"
    $img.on 'load', -> context.success()
    context.$result.append($img)

  data: (args...) ->
    params = args_to_params args
    params.format = 'json'
    query_string = $.param params, true
    json "#{base_url}/render?#{query_string}"

  find: (query) ->
    json "#{base_url}/metrics/find?query=#{encodeURIComponent query}"

  q: (targets...) ->
    _lead: ['q', _lead_to_string: -> targets.join ',']

run = (string) ->
  $entry = $ '<div class="entry"/>'
  $input = $ '<pre class="input cm-s-default">'

  $result = $ '<div class="result">'

  CodeMirror.runMode string, 'coffeescript', $input.get(0)

  $entry.append $input
  $entry.append $result
  context =
    $result: $result
    success: ->
      console.log 'success'
      scroll_to_result()
    failure: ->
      console.log 'failure'
      scroll_to_result()

  ns = create_ns context

  lead.define_functions ns, lead.functions

  `with (ns) {`
  eval "//@ sourceURL=console-coffeescript.js\n" +  CoffeeScript.compile(string, bare: true)
  `}`

  $output.append $entry

