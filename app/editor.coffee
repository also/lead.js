Q = require 'q'
Bacon = require 'baconjs'
_ = require 'underscore'
CodeMirror = require 'codemirror'
React = require 'react'
require 'codemirror/mode/javascript/javascript'
require 'codemirror/mode/coffeescript/coffeescript'
require 'codemirror/addon/hint/show-hint'

Context = require './context'
ContextComponents = require './contextComponents'
Notebook = require './notebook'

user_notebook_keymap = null

update_user_keymap = (keymap) ->
  for k of user_notebook_keymap
    delete user_notebook_keymap[k]
  if keymap?
    _.extend user_notebook_keymap, keymap

init_user_keymap = ->
  # TODO resolve circular imports
  Settings = require './settings'
  unless user_notebook_keymap?
    user_notebook_keymap = {}
    Settings.user_settings.toProperty('editor', 'keymap', 'notebook').onValue update_user_keymap
  user_notebook_keymap

create_editor = (keyMap='notebook') ->
  target = ->
  if is_nodejs?
    return CodeMirror target
  cm = CodeMirror target,
    value: ''
    mode: 'coffeescript'
    keyMap: keyMap
    tabSize: 2
    lineNumbers: true
    viewportMargin: Infinity
    #gutters: ['error']

  if keyMap == 'notebook'
    cm.addKeyMap init_user_keymap()
  cm.setCursor(line: cm.lineCount() - 1)
  cm

set_value = (cm, value) ->
  cm.setValue value
  cm.setCursor(line: cm.lineCount() - 1)

setMinHeight = (cm, minHeight) ->
  cm.display.scroller.style.minHeight = minHeight + 'px'
  cm.refresh()

get_value = (cm) ->
  cm.getValue()

as_event_stream = (cm, event_name, event_transformer) ->
  Bacon.fromBinder (handler) ->
    cm.on event_name, handler
    -> cm.off event_name, handler
  , event_transformer

add_error_mark = (cm, e) ->
  {first_line, first_column, last_line, last_column} = e.location
  if first_line == last_line and first_column == last_column
    line = cm.getLine first_line
    if last_column == line.length
      first_column -= 1
    else
      last_column += 1
  mark = cm.markText {line: first_line, ch: first_column}, {line: last_line, ch: last_column}, {className: 'error'}

  for l in [first_line..last_line]
    gutter = document.createElement 'div'
    gutter.title = e.message
    gutter.innerHTML = '&nbsp;'
    gutter.className = 'errorMarker'
    # TODO make this less annoying, enable it
    #cm.setGutterMarker l, 'error', gutter

  mark

property_path = (cm, token, line) ->
  t = token
  path = []
  loop
    # TODO i don't understand why this isn't `t.start - 1`, but that doesn't work for the first character
    previous_token = cm.getTokenAt CodeMirror.Pos line, t.start
    if t.start == previous_token.start or previous_token.type != 'variable'
      break
    t = previous_token
    if t.string[0] == '.'
      s = t.string.slice 1
    else
      s = t.string
    path.unshift s
  path

token_after = (cm, token, line) ->
  t = token
  last_interesting_token = null
  loop
    # TODO isn't this returning the *last* token?
    next_token = cm.getTokenAt CodeMirror.Pos(line, t.end + 1)
    if t.start == next_token.start
      break
    if next_token.type?
      last_interesting_token = next_token
    t = next_token
  last_interesting_token

collect_string_suggestions = (ctx, string) ->
  Q.all(_.flatten _.map Context.collect_extension_points(ctx, 'suggest_strings'), (fn) -> fn string)
  .then (suggestions) -> _.flatten suggestions

collect_key_suggestions = (ctx, string) ->
  _.flatten _.map Context.collect_extension_points(ctx, 'suggest_keys'), (fn) -> fn string

follow_path = (o, path) ->
  result = o
  for s in path
    return unless result?
    result = result[s]
  # TODO need a better way to identify context functions
  return if result?.module_name?
  result

suggest = (cm, showHints, options) ->
  cur = cm.getCursor()
  token = cm.getTokenAt(cur)
  if token.type is null
    # TODO why only vars here?
    list = (k for k of cm.ctx.imported_vars)
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
    promise = collect_string_suggestions cm.ctx, string
    promise.done (list) ->
      showHints
        list: list
        from: CodeMirror.Pos cur.line, token.start + 1
        to: CodeMirror.Pos cur.line, token.end - end_offset
  else
    if (token.type == 'variable' and token.string[0] == '.') or (token.type == 'error' and token.string == '.')
      path = property_path cm, token, cur.line
      prefix = '.'
      full_s = token.string[1...]
    else
      path = []
      prefix = ''
      full_s = token.string

    sub_s = full_s[...cur.ch-token.start]
    next_token = token_after cm, token, cur.line

    # TODO shouldn't reference inported_context_fns
    imported_context_fns = follow_path cm.ctx.imported_context_fns, path
    imported_vars = follow_path cm.ctx.imported_vars, path

    collect_suggestions = (s) ->
      list = []
      for k, v of imported_context_fns
        # don't suggest the attributes of the fn object
        if k.indexOf(s) is 0
          list.push prefix + k
      for k of imported_vars
        if k.indexOf(s) is 0
          list.push prefix + k

      if path.length == 0
        key_suggestions = collect_key_suggestions cm.ctx, s
        unless next_token?.string is ':'
          key_suggestions = _.map key_suggestions, (k) -> k + ':'

        list.push key_suggestions...
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
  ctx_run: cmd 'Runs the contents of the cell', (cm) ->
    cm.run()

  nb_run: cmd 'Runs the contents of the cell and advances the cursor to the next cell', (cm) ->
    Notebook.run cm.lead_cell, advance: true

  nb_run_in_place: cmd 'Runs the contents of the cell and keeps the cursor in the cell', (cm) ->
    Notebook.run cm.lead_cell, advance: false

  context_help: cmd 'Shows help for the token under the cursor', (cm) ->
    cur = cm.getCursor()
    token = cm.getTokenAt(cur)
    Notebook.context_help cm.lead_cell, token.string

  suggest: cmd 'Suggests a function or metric', (cm) ->
    CodeMirror.showHint cm, suggest, async: true

  fill_with_last_value: cmd 'Replaces the cell with the contents of the previous cell', (cm) ->
    cell = Notebook.input_cell_at_offset cm.lead_cell, -1
    if cell?
      set_value cm, Notebook.cell_value cell
    else
      CodeMirror.Pass

  next_cell: cmd 'Moves the cursor to the next cell', (cm) ->
    unless Notebook.move_focus cm.lead_cell, 1
      CodeMirror.Pass

  previous_cell: cmd 'Moves the cursor to the previous cell', (cm) ->
    unless Notebook.move_focus cm.lead_cell, -1
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
    Notebook.save cm.lead_cell

lead_key_map =
  Tab: (cm) ->
    if cm.somethingSelected()
      cm.indentSelection 'add'
    else
      spaces = Array(cm.getOption("indentUnit") + 1).join(" ")
      cm.replaceSelection(spaces, "end", "+input")
  'Shift-Tab': 'indentLess'
  fallthrough: ['default']

context_key_map =
  'Shift-Enter': 'ctx_run'
  'Ctrl-Enter': 'ctx_run'
  'Ctrl-Space': 'suggest'

  fallthrough: ['lead']

notebook_key_map =
  Up: 'maybe_previous_cell'
  Down: 'maybe_next_cell'
  #'Shift-Up': 'fill_with_last_value'
  'Shift-Enter': 'nb_run'
  'Ctrl-Enter': 'nb_run_in_place'
  'F1': 'context_help'
  'Ctrl-Space': 'suggest'

  fallthrough: ['lead']

# we don't have a real codemirror in node
unless is_nodejs?
  CodeMirror.keyMap.notebook = notebook_key_map
  CodeMirror.keyMap.context = context_key_map
  CodeMirror.keyMap.lead = lead_key_map
  _.extend CodeMirror.commands, commands


EditorComponent = React.createClass
  displayName: 'EditorComponent'
  propTypes:
    run: React.PropTypes.func.isRequired
    initial_value: React.PropTypes.string
  mixins: [ContextComponents.ContextAwareMixin]
  getInitialState: ->
    editor: create_editor 'context'
  run: ->
    @props.run @state.editor.getValue()
  componentDidMount: ->
    editor = @state.editor
    editor.ctx = @state.ctx
    editor.run = @run
    @getDOMNode().appendChild editor.display.wrapper
    if @props.initial_value?
      editor.setValue @props.initial_value
    editor.refresh()
  get_value: ->
    @state.editor.getValue()
  render: ->
    React.DOM.div {className: 'code'}


_.extend exports, {commands, as_event_stream, add_error_mark, create_editor, set_value, get_value, setMinHeight, EditorComponent}
