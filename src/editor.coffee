define (require) ->
  graphite = require 'graphite'
  ops = require 'ops'

  CodeMirror = require 'cm/codemirror'
  require 'cm/javascript'
  require 'cm/coffeescript'
  require 'cm/runmode'
  require 'cm/show-hint'

  require 'lib/stacktrace-min-0.4.js'

  notebook = null
  require ['notebook'], (nb) ->
    notebook = nb

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
      list = (k for k of graphite.function_docs)
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
      graphite.complete string, success: (response) ->
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
        for k of ops
          if k.indexOf(s) is 0
            list.push k
        for k of graphite.function_docs
          if k.indexOf(s) is 0
            list.push k
        for k of graphite.parameter_docs
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

  commands =
    run: cmd 'Runs the contents of the cell and advances the cursor to the next cell', (cm) ->
      notebook.run cm.lead_cell, advance: true

    run_in_place: cmd 'Runs the contents of the cell and keeps the cursor in the cell', (cm) ->
      notebook.run cm.lead_cell, advance: false

    context_help: cmd 'Shows help for the token under the cursor', (cm) ->
      cur = cm.getCursor()
      token = cm.getTokenAt(cur)
      notebook.context_help cm.lead_cell, token.string

    suggest: cmd 'Suggests a function or metric', (cm) ->
      CodeMirror.showHint cm, suggest, async: true

    fill_with_last_value: cmd 'Replaces the cell with the contents of the previous cell', (cm) ->
      cell = notebook.input_cell_at_offset cm.lead_cell, -1
      if cell?
        cm.setValue notebook.cell_value cell
        cm.setCursor(line: cm.lineCount() - 1)
      else
        CodeMirror.Pass

    next_cell: cmd 'Moves the cursor to the next cell', (cm) ->
      unless notebook.move_focus cm.lead_cell, 1
        CodeMirror.Pass

    previous_cell: cmd 'Moves the cursor to the previous cell', (cm) ->
      unless notebook.move_focus cm.lead_cell, -1
        CodeMirror.Pass

    maybe_next_cell: cmd 'Moves the cursor to the next cell if the cursor is at the end', (cm) ->
      cur = cm.getCursor()
      if cur.line is cm.lineCount() - 1
        commands.next_cell cm
      else
        CodeMirror.Pass

    maybe_previous_cell: cmd  'Moves the cursor to the next cell if the cursor is at the end', (cm) ->
      cur = cm.getCursor()
      if cur.line is 0
        commands.previous_cell cm
      else
        CodeMirror.Pass

    save: (cm) ->
      notebook.save cm.lead_cell

  key_map =
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
    'Ctrl-Enter': 'run_in_place'
    'F1': 'context_help'
    'Ctrl-Space': 'suggest'

    fallthrough: ['default']

  {commands, key_map}