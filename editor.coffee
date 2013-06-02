lead._finished = new Object

default_options = {}
define_parameters = true

previously_run = null
lead.graphite.load_docs()

token_after = (cm, token, line) ->
  t = token
  last_interesting_token = null
  loop
    next_token = cm.getTokenAt CodeMirror.Pos(line, t.end + 1)
    if t.start == next_token.start
      break
    if next_token.type?
      last_interesting_token = next_token
    t = next_token
  last_interesting_token

suggest = (cm, showHints, options) ->
  cur = cm.getCursor()
  token = cm.getTokenAt(cur)
  if token.type is null
    list = (k for k of lead.graphite.function_docs)
    showHints
      list: list
      from: CodeMirror.Pos cur.line, token.end
      to: CodeMirror.Pos cur.line, token.end
  else if token.type is 'string'
    open = token.string[0]
    string = token.string[1..]
    close = string[string.length - 1]
    if open == close
      string = string[...-1]
      end_offset = 1
    else
      end_offset = 0
    lead.graphite.complete string, success: (response) ->
      list = (node.path for node in response.metrics)
      showHints
        list: list
        from: CodeMirror.Pos cur.line, token.start + 1
        to: CodeMirror.Pos cur.line, token.end - end_offset
  else
    full_s = token.string
    sub_s = full_s[...cur.ch-token.start]
    next_token = token_after cm, token, cur.line
    collect_suggestions = (s) ->
      list = []
      for k of lead.ops
        if k.indexOf(s) is 0
          list.push k
      for k of lead.graphite.function_docs
        if k.indexOf(s) is 0
          list.push k
      for k of lead.graphite.parameter_docs
        if k.indexOf(s) is 0
          suggestion = k
          suggestion += ': ' unless next_token?.string is ':'
          list.push suggestion
      list
    list = collect_suggestions full_s
    if list.length > 0
      showHints
        list: list
        from: CodeMirror.Pos cur.line, token.start
        to: CodeMirror.Pos cur.line, token.end
    else
      list = collect_suggestions sub_s
      showHints
        list: list
        from: CodeMirror.Pos cur.line, token.start
        to: CodeMirror.Pos cur.line, cur.ch

window.init_editor = ->
  CodeMirror.commands.run = (cm) ->
    setTimeout(-> run cm.getValue(), 1)

  CodeMirror.commands.contextHelp = (cm) ->
    cur = editor.getCursor()
    token = cm.getTokenAt(cur)
    if lead.graphite.has_docs token.string
      run "docs '#{token.string}'"
    else if create_ns()[token.string]?
      run "help #{token.string}"

  CodeMirror.commands.suggest = (cm) ->
    CodeMirror.showHint cm, suggest, async: true

  CodeMirror.keyMap.lead =
    Tab: (cm) ->
      if cm.somethingSelected()
        cm.indentSelection 'add'
      else
        spaces = Array(cm.getOption("indentUnit") + 1).join(" ")
        cm.replaceSelection(spaces, "end", "+input")
    fallthrough: ['default']

  $code = $ '#code'
  $output = $ '#output'

  editor = CodeMirror $code.get(0),
    mode: 'coffeescript'
    keyMap: 'lead'
    tabSize: 2
    autofocus: true
    viewportMargin: Infinity
    gutters: ['error']
    extraKeys:
      'Shift-Enter': 'run'
      'F1': 'contextHelp'
      'Ctrl-Space': 'suggest'

  editor.on 'viewportChange', ->
    $('html, body').scrollTop $(document).height()

  error_marks = []

  compile = ->
    m.clear() for m in error_marks
    editor.clearGutter 'error'
    try
      CoffeeScript.compile editor.getValue()
    catch e
      {first_line, first_column, last_line, last_column} = e.location
      if first_line == last_line and first_column == last_column
        line = editor.getLine first_line
        if last_column == line.length
          first_column -= 1
        else
          last_column += 1
      mark = editor.markText {line: first_line, ch: first_column}, {line: last_line, ch: last_column}, {className: 'error'}
      error_marks = [mark]

      for l in [first_line..last_line]
        gutter = document.createElement 'div'
        gutter.title = e.message
        gutter.innerHTML = '&nbsp;'
        gutter.className = 'errorMarker'
        # TODO make this less annoying, enable it
        #editor.setGutterMarker l, 'error', gutter

  compile_timeout = null
  editor.on 'change', ->
    clearTimeout compile_timeout
    compile_timeout = setTimeout compile, 200

  scroll_to_result = ($result)->
    top = if $result?
      $result.offset().top
    else
      $(document).height()

    setTimeout ->
      $('html, body').scrollTop top
    , 10

  set_code = (code) ->
    editor.setValue code
    editor.focus()
    editor.setCursor(line: editor.lineCount() - 1)

  run = (string) ->
    $entry = $ '<div class="entry"/>'
    $input = $ '<div class="input"><span class="close"/></div>'
    $pre = $ '<pre/>'
    $input.on 'click', (e) ->
      if $(e.target).hasClass 'close'
        $entry.remove()
      else
        set_code string

    $result = $ '<div class="result">'

    CodeMirror.runMode string, 'coffeescript', $pre.get(0)
    $input.append $pre

    $entry.append $input
    $output.append $entry
    scroll_to_result $entry

    context =
      current_options: {}
      default_options: default_options
      $result: $result
      success: ->
        scroll_to_result $entry
        lead._finished
      failure: ->
        scroll_to_result $entry
        lead._finished
      set_code: set_code
      run: run
      clear_output: -> $output.empty()
      previously_run: previously_run
      hide_input: -> $input.hide()

    bind_op = (op) ->
      bound = (args...) -> op.fn.apply context, args
      bound._lead_op = op
      bound

    ops = {}
    for k, op of lead.ops
      ops[k] = bind_op op

    if define_parameters
      for k of lead.graphite.parameter_docs
        do (k) ->
          fn = (value) ->
            if value?
              @current_options[k] = value
            else
              @current_options[k] ? @default_options[k]

          ops[k] = bind_op
            name: k
            fn: fn
            cli_fn: ->
              @cli.object @cli[k]()
    
    context.cli = ops

    functions = {}

    handle_exception = (e, compiled) ->
      error printStackTrace({e}).join('\n')
      ops.text 'Compiled JavaScript:'
      ops.source 'javascript', compiled

    error = (message) ->
      $pre = $ '<pre class="error"/>'
      $pre.text message
      context.$result.append $pre
      context.failure()

    lead.define_functions functions, lead.functions
    try
      compiled = CoffeeScript.compile(string, bare: true) + "\n//@ sourceURL=console-coffeescript.js"
    catch e
      if e instanceof SyntaxError
        error "Syntax Error: #{e.message} at #{e.location.first_line + 1}:#{e.location.first_column + 1}"
      else
        handle_exception e, compiled

    if compiled?
      try
        `with (ops) { with (functions) {`
        result = eval compiled
        `}}`
        unless result == lead._finished
          if result?._lead_op?
            result._lead_op.cli_fn.apply(context)
          else if lead.is_lead_node result
            lead_string = lead.to_string result
            if $.type(result) == 'function'
              ops.text "#{lead_string} is a Graphite function"
              run "docs #{result.values[0]}"
            else
              ops.text "What do you want to do with #{lead_string}?"
              for f in ['data', 'graph', 'img', 'url']
                ops.example "#{f} #{result.to_js_string()}"
          else
            ops.object result
        previously_run = string
      catch e
        handle_exception e, compiled

    $entry.append $result

  if location.search isnt ''
    run atob decodeURIComponent location.search[1..]
  else
    run 'intro'
