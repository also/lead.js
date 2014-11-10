$ = require 'jquery'
_ = require 'underscore'
URI = require 'URIjs'
Bacon = require 'bacon.model'
Editor = require './editor'
http = require './http'
Context = require './context'
modules = require './modules'
React = require 'react/addons'
CoffeeScriptCell = require './coffeescript_cell'
Markdown = require './markdown'
Builtins = require './builtins'
Documentation = require './documentation'
Components = require './components'

modules.export exports, 'notebook', ({component_fn, fn, cmd, component_cmd}) ->
  component_cmd 'save', 'Saves the current notebook to a file', (ctx) ->
    link = save ctx.notebook, ctx.input_cell
    React.DOM.a {href: link.href}, 'Download Notebook'

  cmd 'load_file', 'Loads a notebook from a file', (ctx) ->
    open_file_picker ctx

  component_fn 'load', 'Loads a script from a URL', (ctx, url, options={}) ->
    promise = http.execute_xhr(url, dataType: 'text', type: 'get')
    .fail (response) ->
      throw response.statusText
    .then (xhr) ->
      handle_file ctx,
        filename: URI(url).filename()
        type: xhr.getResponseHeader 'content-type'
        content: xhr.responseText
      , options

    Context.AsyncComponent {promise},
      Builtins.ComponentAndError {promise},
        "Loading #{url}"
      Builtins.PromiseStatusComponent {promise, start_time: new Date}

  cmd 'clear', 'Clears the notebook', (ctx) ->
    clear_notebook ctx.notebook

notebook_content_type = 'application/x-lead-notebook'

forwards = +1
backwards = -1

cell_key = 0

# predicates for cells
is_input = (cell) -> cell.type is 'input'
is_output = (cell) -> cell.type is 'output'
is_clean = (cell) -> Editor.get_value(cell.editor) is '' and not cell.used
visible = (cell) -> cell.visible
identity = (cell) -> true

InputOutputComponent = React.createClass
  displayName: 'InputOutputComponent'
  mixins: [React.addons.PureRenderMixin]
  render: ->
    React.DOM.div {className: 'io'},
      @props.input_cell?.component cell: @props.input_cell, key: @props.input_cell.key
      @props.output_cell?.component cell: @props.output_cell, key: @props.output_cell.key

DocumentComponent = React.createClass
  displayName: 'DocumentComponent'
  mixins: [Components.ObservableMixin]
  get_observable: (props) -> props.cells_model
  render: ->
    props = null
    ios = []
    _.each @state.value, (cell) ->
      if cell.type == 'input'
        props = input_cell: cell, key: cell.key
        ios.push props
      else
        if !props? or props.input_cell.output_cell != cell
          ios.push output_cell: cell, key: cell.key
        else
          props.output_cell = cell
        props = null

    React.DOM.div {className: 'notebook'}, _.map ios, InputOutputComponent

NotebookComponent = React.createClass
  displayName: 'NotebookComponent'
  propTypes:
    imports: React.PropTypes.arrayOf(React.PropTypes.string)
    module_names: React.PropTypes.arrayOf(React.PropTypes.string)
    init: React.PropTypes.func
  getInitialState: ->
    # FIXME #175 props can change
    notebook = create_notebook @props
    @props.init? notebook
    notebook: notebook
  shouldComponentUpdate: ->
    # never changes, handled by document
    false
  render: ->
    DocumentComponent {cells_model: @state.notebook.cells_model}

create_notebook = (opts) ->
  $file_picker = $ '<input type="file" id="file" class="file_picker"/>'
  $file_picker.on 'change', (e) ->
    for file in e.target.files
      load_file notebook.opening_run_context, file

    notebook.opening_run_context = null
    # reset the file picker so change is triggered again
    $file_picker.val ''

  cells_model = Bacon.Model([])
  document = DocumentComponent {cells_model}
  # FIXME add file picker
  notebook =
    context: opts.context
    cells: []
    cells_model: cells_model
    input_number: 1
    output_number: 1
    component: document
    $file_picker: $file_picker
    cell_run: new Bacon.Bus
    cell_focused: new Bacon.Bus

  unless is_nodejs?
    scrolls = $(window).asEventStream 'scroll'
    # FIXME if anything else subscribes to output_cell.done, scroll_to never gets any events
    scroll_to = notebook.cell_run.flatMapLatest (input_cell) ->
      # TODO without the delay, this can happen before there is a dom node.
      # not sure if the ordering now is guaranteed
      #
      # FIXME busted with webpack/possible Bacon update
      input_cell.output_cell.done.delay(0).takeUntil scrolls
    scroll_to.onValue (output_cell) ->
      # FIXME
      $('html, body').scrollTop $(output_cell.dom_node).offset().top

  base_context = Context.create_base_context(opts)
  notebook.base_context = base_context
  notebook

export_notebook = (notebook, current_cell) ->
  lead_js_version: 0
  cells: notebook.cells.filter((cell) -> cell != current_cell and is_input cell).map (cell) ->
    type: 'input'
    value: Editor.get_value cell.editor

import_notebook = (notebook, cell, imported, options) ->
  cells = _.map imported.cells, (imported_cell) ->
    if imported_cell.type is 'input'
      cell = add_input_cell notebook, after: cell
      set_cell_value cell, imported_cell.value
      cell
  if options.run
    _.each cells, run
  notebook

update_view = (notebook) ->
  notebook.cells_model.set notebook.cells.slice()

clear_notebook = (notebook) ->
  for cell in notebook.cells
    cell.active = false
  notebook.cells.length = 0
  focus_cell add_input_cell notebook

cell_index = (cell) ->
  cell.notebook.cells.indexOf cell

seek = (start_cell, direction, predicate=identity) ->
  notebook = start_cell.notebook
  index = cell_index(start_cell) + direction
  loop
    cell = notebook.cells[index]
    return unless cell?
    return cell if predicate cell
    index += direction

input_cell_at_offset = (cell, offset) ->
  seek cell, offset, is_input

get_input_cell_by_number = (notebook, number) ->
  for cell in notebook
    return cell if cell.number == number and is_input cell

remove_cell = (cell) ->
  index = cell_index cell
  cell.notebook.cells.splice index, 1
  cell.active = false
  update_view cell.notebook

insert_cell = (cell, position) ->
  # TODO is it still possible to end up with cells that aren't active?
  if position?.before?.active
    offset = 0
    current_cell = position.before
  else if position?.after?.active
    offset = 1
    current_cell = position.after
  else
    cell.notebook.cells.push cell
    update_view cell.notebook
    return

  index = cell_index current_cell
  current_cell.notebook.cells.splice index + offset, 0, cell
  update_view cell.notebook

# TODO cell type
add_input_cell = (notebook, opts={}) ->
  if opts.reuse
    if opts.after?
      cell = seek opts.after, forwards, (cell) -> is_input(cell) and visible(cell)
    else if opts.before?
      cell = seek opts.before, backwards, (cell) -> is_input(cell) and visible(cell)
  unless cell? and is_clean cell
    cell = create_input_cell notebook
    insert_cell cell, opts
  cell

InputCellComponent = React.createClass
  displayName: 'InputCellComponent'
  mixins: [Components.ObservableMixin, React.addons.PureRenderMixin]
  get_observable: (props) -> props.cell.changes
  render: ->
    React.DOM.div {className: 'cell input', 'data-cell-number': @props.cell.number},
      React.DOM.span({className: 'permalink', onClick: @permalink_link_clicked}, React.DOM.i {className: 'fa fa-link'}),
      React.DOM.div({className: 'code', ref: 'code'})

  componentDidMount: ->
    editor = @props.cell.editor
    @refs.code.getDOMNode().appendChild editor.display.wrapper
    editor.refresh()

  permalink_link_clicked: -> generate_permalink @props.cell

generate_permalink = (cell) ->
  run_without_input_cell cell.notebook, after: cell.output_cell ? cell, (ctx) ->
    Builtins.context_fns.permalink.fn ctx
    Context.IGNORE

create_input_cell = (notebook) ->
  editor = Editor.create_editor()
  cell =
    type: 'input'
    key: "input#{cell_key++}"
    visible: true
    active: true
    notebook: notebook
    context: create_input_context notebook
    used: false
    changes: new Bacon.Bus()
    editor: editor
    editor_changes: Editor.as_event_stream editor, 'change'

  editor.lead_cell = cell
  editor.ctx = cell.context
  cell.component = InputCellComponent

  # scan changes for the side effect in recompile
  # we have to subscribe so that the events are sent
  cell.editor_changes.debounce(200).scan([], CoffeeScriptCell.recompile).onValue ->

  cell

set_cell_value = (cell, value) ->
  Editor.set_value cell.editor, value

focus_cell = (cell) ->
  # hack around not understanding how this plays with react
  # https://github.com/facebook/react/issues/1791
  setTimeout ->
    cell.editor.focus()
    cell.notebook.cell_focused.push cell
  , 0

OutputCellComponent = React.createClass
  displayName: 'OutputCellComponent'
  mixins: [Components.ObservableMixin, React.addons.PureRenderMixin]
  get_observable: (props) -> props.cell.component_model
  render: -> React.DOM.div {className: 'cell output', 'data-cell-number': @props.cell.number}, @state.value?()
  componentDidMount: ->
    @props.cell.dom_node = @getDOMNode()

create_output_cell = (notebook) ->
  number = notebook.output_number++

  cell =
    component_model: new Bacon.Model null
    type: 'output'
    key: "output#{cell_key++}"
    visible: true
    active: true
    notebook: notebook
    number: number

  cell.component = OutputCellComponent
  cell

run = (input_cell) ->
  output_cell = create_output_cell input_cell.notebook
  input_cell.used = true
  remove_cell input_cell.output_cell if input_cell.output_cell?
  input_cell.output_cell = output_cell
  insert_cell output_cell, after: input_cell
  input_cell.number = input_cell.notebook.input_number++
  input_cell.changes.push input_cell

  # TODO cell type
  run_context = Context.create_run_context [input_cell.notebook.context, input_cell.context, {input_cell, output_cell}, create_notebook_run_context input_cell]
  fn = CoffeeScriptCell.get_fn run_context
  run_with_context run_context, fn
  input_cell.notebook.cell_run.push input_cell
  output_cell

run_with_context = (ctx, fn) ->
  output_cell = ctx.output_cell
  changes = ctx.changes
  # pending is a property that has the initial value 0 and tracks the number of pending promises
  pending = ctx.pending
  has_pending = pending.map (n) -> n > 0
  # a cell is "done enough" if there were no async tasks,
  # or when the first async task completes
  no_longer_pending = ctx.changes.skipWhile has_pending
  output_cell.done = no_longer_pending.take(1).map -> output_cell
  Context.run_in_context ctx, fn

  # TODO Bacon calls the function passed to set
  output_cell.component_model.set -> ctx.component

create_bare_output_cell_and_context = (notebook) ->
  output_cell = create_output_cell notebook
  run_context = Context.create_run_context [notebook.context, create_input_context(notebook), {output_cell}, create_notebook_run_context(output_cell)]
  run_context

run_without_input_cell = (notebook, position, fn) ->
  run_context = create_bare_output_cell_and_context notebook
  insert_cell run_context.output_cell, position
  run_with_context run_context, fn

create_input_context = (notebook) ->
  Context.create_context notebook.base_context

create_notebook_run_context = (cell) ->
  notebook = cell.notebook
  notebook: notebook
  # TODO rename
  set_code: (code) ->
    # TODO coffeescript
    cell = add_input_cell notebook, after: @output_cell
    set_cell_value cell, code
    focus_cell cell
  run: (code) ->
    # TODO coffeescript
    cell = add_input_cell notebook, after: @output_cell
    set_cell_value cell, code
    run cell
  # TODO does it make sense to use output cells here?
  previously_run: -> Editor.get_value input_cell_at_offset(cell, -1).editor
  export_notebook: -> export_notebook notebook, cell
  get_input_value: (number) ->
    Editor.get_value get_input_cell_by_number(notebook, number)?.editor

open_file_picker = (run_context) ->
  run_context.notebook.opening_run_context = run_context
  run_context.notebook.$file_picker.trigger 'click'

handle_file = (ctx, file, options={}) ->
  if file.type.indexOf('image') < 0
    [prefix..., extension] = file.filename.split '.'
    if extension is 'coffee'
      cell = add_input_cell ctx.notebook, after: ctx.output_cell
      # TODO cell type
      set_cell_value cell, file.content
      if options.run
        run cell
    else if extension is 'md'
      run_without_input_cell ctx.notebook, after: ctx.output_cell, (ctx) ->
        Context.add_component ctx, Markdown.MarkdownComponent value: file.content, opts: {base_href: file.base_href}
        Context.IGNORE
    else
      try
        imported = JSON.parse file.content
      catch e
        Builtins.context_fns.error.fn ctx, "File #{file.filename} isn't a lead.js notebook:\n#{e}"
        return
      version = imported.lead_js_version
      unless version?
        Builtins.context_fns.error.fn ctx "File #{file.filename} isn't a lead.js notebook"
        return
      import_notebook ctx.notebook, ctx.output_cell, imported, options

load_file = (ctx, file) ->
  if file.type.indexOf('image') < 0
    reader = new FileReader
    reader.onload = (e) ->
      handle_file ctx,
        filename: file.name
        content: e.target.result
        type: file.type

    reader.readAsText file

save = (input_cell) ->
  text = JSON.stringify export_notebook input_cell
  blob = new Blob [text], type: notebook_content_type
  link = document.createElement 'a'
  link.href = window.webkitURL.createObjectURL blob
  link.download = 'notebook.lnb'
  link.click()
  link

_.extend exports, {
  NotebookComponent
  input_cell_at_offset
  add_input_cell
  remove_cell
  focus_cell
  run_without_input_cell
  set_cell_value

  run: (cell, opts={advance: true}) ->
    output_cell = run cell
    if opts.advance
      new_cell = add_input_cell cell.notebook, after: output_cell, reuse: true
      focus_cell new_cell

  handle_file: handle_file

  save: (cell) ->
    run_without_input_cell cell.notebook, before: cell, (ctx) ->
      exports.context_fns.save.fn ctx
      Context.IGNORE

  context_help: (cell, token) ->
    key = Documentation.get_key cell.context, token
    run_without_input_cell cell.notebook, before: cell, (ctx) ->
      if key?
        Context.add_component ctx, Builtins.help_component ctx, Documentation.key_to_string key
      Context.IGNORE

  move_focus: (cell, offset) ->
    new_cell = input_cell_at_offset cell, offset
    if new_cell?
      focus_cell new_cell
      true
    else
      false

  cell_value: (cell) ->
    cell.editor.getValue()
}
