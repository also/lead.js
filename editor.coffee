lead._ignore = new Object

default_options = {}
define_parameters = true

$document = null
$file_picker = null

lead.notebook_content_type = 'application/x-lead-notebook'

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

cmd = (doc, fn) ->
  fn.doc = doc
  fn

lead_editor_commands =
  run: cmd 'Runs the contents of the cell', (cm) ->
    cm.lead_cell.run()
    add_context()

  contextHelp: cmd 'Shows help for the token under the cursor', (cm) ->
    cur = cm.getCursor()
    token = cm.getTokenAt(cur)
    if lead.graphite.has_docs token.string
      run_in_info_context cm.lead_cell, "docs '#{token.string}'"
    else if lead.ops[token.string]?
      run_in_info_context cm.lead_cell, "help #{token.string}"

  suggest: cmd 'Suggests a function or metric', (cm) ->
    CodeMirror.showHint cm, suggest, async: true

  fill_with_last_value: cmd 'Replaces the cell with the contents of the previous cell', (cm) ->
    previous_context = input_cell_at_offset cm.lead_cell, -1
    if previous_context?
      cm.setValue previous_context.editor.getValue()
      cm.setCursor(line: cm.lineCount() - 1)
    else
      CodeMirror.Pass

  next_cell: cmd 'Moves the cursor to the next cell', (cm) ->
    cell = input_cell_at_offset cm.lead_cell, 1
    if cell?
      cell.editor.focus()
    else
      CodeMirror.Pass

  previous_cell: cmd 'Moves the cursor to the previous cell', (cm) ->
    cell = input_cell_at_offset cm.lead_cell, -1
    if cell?
      cell.editor.focus()
    else
      CodeMirror.Pass

  maybe_next_cell: cmd 'Moves the cursor to the next cell if the cursor is at the end', (cm) ->
    cur = cm.getCursor()
    if cur.line is cm.lineCount() - 1
      lead_editor_commands.next_cell cm
    else
      CodeMirror.Pass

  maybe_previous_cell: cmd  'Moves the cursor to the next cell if the cursor is at the end', (cm) ->
    cur = cm.getCursor()
    if cur.line is 0
      lead_editor_commands.previous_cell cm
    else
      CodeMirror.Pass

  save: (cm) ->
    run_in_info_context cm.lead_cell, 'save'

lead_key_map =
  Tab: (cm) ->
    if cm.somethingSelected()
      cm.indentSelection 'add'
    else
      spaces = Array(cm.getOption("indentUnit") + 1).join(" ")
      cm.replaceSelection(spaces, "end", "+input")
  Up: 'maybe_previous_cell'
  Down: 'maybe_next_cell'
  'Shift-Up': 'fill_with_last_value'
  'Shift-Enter': 'run'
  'F1': 'contextHelp'
  'Ctrl-Space': 'suggest'

  fallthrough: ['default']

init_codemirror = ->
  CodeMirror.keyMap.lead = lead_key_map
  $.extend CodeMirror.commands, lead_editor_commands

contexts = []

export_notebook = (current_cell) ->
  lead_js_version: 0
  cells: contexts.filter((cell) -> cell != current_cell).map (cell) ->
    type: 'input'
    value: cell.editor.getValue()

import_notebook = (notebook, options) ->
  for cell in notebook.cells
    if cell.type is 'input'
      if options.run
        run_in_available_context cell.value
      else
        add_context cell.value

clear_contexts = ->
  $document.empty()
  contexts = []

input_cell_at_offset = (cell, offset) ->
  index = contexts.indexOf cell
  contexts[index + offset]

get_available_input_cell = ->
  last = contexts[contexts.length - 1]
  if last?.is_clean()
    return last
  else
    return null

remove_cell = (cell) ->
  index = contexts.indexOf cell
  cell.$el.remove()
  contexts.splice index, 1

add_context = (code='') ->
  cell = get_available_input_cell()
  if cell?
    cell.editor.setValue code
  else
    cell = create_input_cell code
    $document.append cell.$el
    cell.rendered()
    contexts.push cell

  {editor} = cell
  editor.focus()
  editor.setCursor(line: editor.lineCount() - 1)
  cell

run_in_available_context = (code) ->
  add_context(code).run()
  add_context()

# Add an input cell above the last input cell
run_in_info_context = (current_cell, code) ->
  cell = create_input_cell code
  if current_cell?
    current_cell.$el.before cell.$el
    index = contexts.indexOf cell
  else
    $document.append cell.$el
    index = -1
  cell.rendered()
  contexts.splice index, 0, cell
  cell.run code

create_input_cell = (code) ->
  $el = $ '<div class="cell input"/>'
  $code = $ '<div class="code"/>'
  $el.append $code

  editor = CodeMirror $code.get(0),
    value: code
    mode: 'coffeescript'
    keyMap: 'lead'
    tabSize: 2
    viewportMargin: Infinity
    gutters: ['error']

  context =
    used: false
    editor: editor
    rendered: -> editor.refresh()
    $el: $el
    hide: -> $el.hide()
    is_clean: -> editor.getValue() is '' and not @.used
    run: ->
      context.used = true
      context.output_cell?.$el.remove()
      context.output_cell = run context, editor.getValue()

  editor.lead_cell = context

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
    compile_timeout = setTimeout (-> compile editor), 200

  context

bind_cli = (run_context) ->
  bind_op = (op) ->
    bound = (args...) ->
      # if the runction returned a value, unwrap it. otherwise, ignore it
      op.fn.apply(run_context, args)?._lead_cli_value ? lead._ignore
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
            @value @current_options[k] ? @default_options[k]

        ops[k] = bind_op
          name: k
          fn: fn
          cli_fn: ->
            @cli.object @cli[k]()
  ops

run = (input_cell, string) ->
  $el = $ '<div class="cell output"/>'

  input_cell.$el.after $el
  $top = input_cell.$el

  scroll_to_result = ($result)->
    top = if $result?
      $result.offset().top
    else
      $(document).height()

    setTimeout ->
      $('html, body').scrollTop top
    , 10

  output = ($target) ->
    (output) ->
      $item = $ '<div class="item"/>'
      if output?
        $item.append output
      $target.append $item
      $item

  run_context =
    current_options: {}
    default_options: default_options
    output: output $el
    success: ->
      scroll_to_result $top
      lead._ignore
    failure: ->
      scroll_to_result $top
      lead._ignore
    set_code: add_context
    run: run_in_available_context
    clear_output: -> clear_contexts()
    previously_run: -> input_cell_at_offset(input_cell, -1).editor.getValue()
    hide_input: -> remove_cell input_cell
    value: (value) -> _lead_cli_value: value
    open_file: open_file_picker
    export_notebook: -> export_notebook input_cell
    save: ->
      text = JSON.stringify export_notebook input_cell
      blob = new Blob [text], type: lead.notebook_content_type
      link = document.createElement 'a'
      link.innerHTML = 'Download Notebook'
      link.href = window.webkitURL.createObjectURL blob
      link.download = 'notebook.lnb'
      link.click()
      @output link

    async: (fn) ->
      $item = $ '<div class="async"/>'
      $item.attr 'data-async-status', 'loading'
      @output $item

      start_time = new Date

      duration = ->
        ms = new Date - start_time
        if ms >= 1000
          s = (ms / 1000).toFixed 1
          "#{s} s"
        else
          "#{ms} ms"

      nested_context = $.extend {}, run_context,
        output: output $item
        success: ->
          $item.attr 'data-async-status', "loaded in #{duration()}"
        failure: ->
          $item.attr 'data-async-status', "failed in #{duration()}"
      nested_context.cli = bind_cli nested_context
      fn.call(nested_context)


  run_context.cli = ops = bind_cli run_context

  functions = {}

  handle_exception = (e, compiled) ->
    ops.error printStackTrace({e}).join('\n')
    ops.text 'Compiled JavaScript:'
    ops.source 'javascript', compiled

  error = (message) ->
    $pre = $ '<pre class="error"/>'
    $pre.text message
    run_context.output $pre
    run_context.failure()

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
      unless result == lead._ignore
        if result?._lead_op?
          result._lead_op.cli_fn.apply(run_context)
        else if lead.is_lead_node result
          lead_string = lead.to_string result
          if $.type(result) == 'function'
            ops.text "#{lead_string} is a Graphite function"
            run_in_info_context input_cell, "docs #{result.values[0]}"
          else
            ops.text "What do you want to do with #{lead_string}?"
            for f in ['data', 'graph', 'img', 'url']
              ops.example "#{f} #{result.to_js_string()}"
        else
          ops.object result
    catch e
      handle_exception e, compiled

  $el: $el

opening_run_context = null

open_file_picker = (run_context) ->
  opening_run_context = run_context
  $file_picker.trigger 'click'

lead.handle_file = (run_context, file, options={}) ->
  if file.type.indexOf('image') < 0
    [_..., extension] = file.filename.split '.'
    if extension is 'coffee'
      if options.run
        run_in_available_context file.content
      else
        add_context file.content
    else
      try
        notebook = JSON.parse file.content
      catch e
        run_context.cli.error "File #{file.filename} isn't a lead.js notebook:\n#{e}"
        return
      version = notebook.lead_js_version
      unless version?
        run_context.cli.error "File #{file.filename} isn't a lead.js notebook"
        return
      import_notebook notebook, options

load_file = (run_context, file) ->
  if file.type.indexOf('image') < 0
    reader = new FileReader
    reader.onload = (e) ->
      lead.handle_file run_context,
        filename: file.name
        content: e.target.result
        type: file.type

    reader.readAsText file

window.init_editor = ->
  init_codemirror()
  $document = $ '#document'
  $file_picker = $ '#file'

  $file_picker.on 'change', (e) ->
    for file in e.target.files
      load_file opening_run_context, file

    opening_run_context = null
    # reset the file picker so change is triggered again
    $file_picker.val ''

  rc = localStorage.lead_rc
  if rc?
    run_in_available_context rc

  uri = URI location.href
  fragment = uri.fragment()
  if fragment.length > 0 and fragment[0] == '/'
    id = fragment[1..]
    run_in_available_context "gist #{JSON.stringify id}, run: true; quiet"
  else
    program = if location.search isnt ''
      atob decodeURIComponent location.search[1..]
    else
      'intro'

    run_in_available_context program
