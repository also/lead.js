$ = require 'jquery'
_ = require 'underscore'
URI = require 'URIjs'
Bacon = require 'bacon.model'
Editor = require './editor'
http = require './http'
graphite = require './graphite'
context = require './context'
modules = require './modules'
React = require './react_abuse'
CoffeeScriptCell = require './coffeescript_cell'

modules.export exports, 'notebook', ({cmd}) ->
  cmd 'save', 'Saves the current notebook to a file', ->
    link = save @notebook, @input_cell
    @add_component React.DOM.a {href: link.href}, 'Download Notebook'

  cmd 'load', 'Loads a script from a URL', (url, options={}) ->
    if arguments.length is 0
      open_file_picker @
    else
      @async ->
        promise = http.execute_xhr url, dataType: 'text', type: 'get'
        promise.then (xhr) =>
          handle_file @,
            filename: URI(url).filename()
            type: xhr.getResponseHeader 'content-type'
            content: xhr.responseText
          , options
        promise.fail (response) =>
          @error response.statusText
        promise

  cmd 'clear', 'Clears the notebook', ->
    clear_notebook @notebook

  notebook_content_type = 'application/x-lead-notebook'

  forwards = +1
  backwards = -1

  # predicates for cells
  is_input = (cell) -> cell.type is 'input'
  is_output = (cell) -> cell.type is 'output'
  is_clean = (cell) -> Editor.get(value cell.editor) is '' and not cell.used
  visible = (cell) -> cell.visible
  identity = (cell) -> true

  DocumentComponent = React.createClass
    displayName: 'DocumentComponent'
    mixins: [React.ObservableMixin]
    get_observable: -> @props.cells_model
    render: ->
      React.DOM.div {className: 'document'}, _.pluck @state.value, 'component'

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

    context.create_base_context(opts).then (base_context) ->
      notebook.base_context = base_context
      notebook

  export_notebook = (notebook, current_cell) ->
    lead_js_version: 0
    cells: notebook.cells.filter((cell) -> cell != current_cell and is_input cell).map (cell) ->
      type: 'input'
      value: Editor.get_value cell.editor

  import_notebook = (notebook, cell, imported, options) ->
    for imported_cell in imported.cells
      if imported_cell.type is 'input'
        cell = add_input_cell notebook, after: cell
        set_cell_value cell, imported_cell.value
        if options.run
          run cell
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

  InputCellComponent = React.createIdentityClass
    displayName: 'InputCellComponent'
    mixins: [React.ObservableMixin]
    get_observable: -> @props.cell.changes
    render: ->
      # TODO handle hiding
      React.DOM.div {className: 'cell input', 'data-cell-number': @props.cell.number},
        React.DOM.span({className: 'permalink', onClick: @permalink_link_clicked}, 'link'),
        React.DOM.div({className: 'code', ref: 'code'})

    componentDidMount: ->
      editor = @props.cell.editor
      @refs.code.getDOMNode().appendChild editor.display.wrapper
      editor.refresh()

    permalink_link_clicked: -> generate_permalink @props.cell

  generate_permalink = (cell) ->
    run_without_input_cell cell.notebook, after: cell.output_cell ? cell, ->
      @permalink()

  create_input_cell = (notebook) ->
    editor = Editor.create_editor ->
    cell =
      type: 'input'
      visible: true
      active: true
      notebook: notebook
      context: create_input_context notebook
      used: false
      changes: new Bacon.Bus()
      editor: editor
      editor_changes: Editor.as_event_stream editor, 'change'

    editor.lead_cell = cell
    component = InputCellComponent {cell}
    cell.component = component

    # scan changes for the side effect in recompile
    # we have to subscribe so that the events are sent
    cell.editor_changes.debounce(200).scan([], CoffeeScriptCell.recompile).onValue ->

    cell

  set_cell_value = (cell, value) ->
    Editor.set_value cell.editor, value

  focus_cell = (cell) ->
    cell.editor.focus()
    cell.notebook.cell_focused.push cell

  OutputCellComponent = React.createIdentityClass
    displayName: 'OutputCellComponent'
    mixins: [React.ObservableMixin]
    get_observable: -> @props.cell.component_model
    render: -> React.DOM.div {className: 'cell output clean', 'data-cell-number': @props.cell.number}, @state.value
    componentDidMount: ->
      @props.cell.dom_node = @getDOMNode()

  create_output_cell = (notebook) ->
    number = notebook.output_number++

    cell =
      component_model: new Bacon.Model null
      type: 'output'
      visible: true
      active: true
      notebook: notebook
      number: number

    cell.component = OutputCellComponent {cell}
    cell

  run = (input_cell) ->
    output_cell = create_output_cell input_cell.notebook
    input_cell.used = true
    remove_cell input_cell.output_cell if input_cell.output_cell?
    insert_cell output_cell, after: input_cell
    input_cell.number = input_cell.notebook.input_number++
    input_cell.changes.push input_cell
    input_cell.output_cell = output_cell

    # TODO cell type
    run_context = context.create_run_context [input_cell.context, {input_cell, output_cell}, create_notebook_run_context input_cell]
    fn = CoffeeScriptCell.get_fn run_context
    run_with_context run_context, fn
    input_cell.notebook.cell_run.push input_cell
    output_cell

  run_with_context = (run_context, fn) ->
    output_cell = run_context.output_cell
    changes = run_context.changes
    # pending is a property that has the initial value 0 and tracks the number of pending promises
    pending = run_context.pending
    has_pending = pending.map (n) -> n > 0
    # a cell is "done enough" if there were no async tasks,
    # or when the first async task completes
    no_longer_pending = run_context.changes.skipWhile has_pending
    output_cell.done = no_longer_pending.take(1).map -> output_cell
    context.run_in_context run_context, fn

    output_cell.component_model.set run_context.component

  create_bare_output_cell_and_context = (notebook) ->
    output_cell = create_output_cell notebook
    run_context = context.create_run_context [create_input_context(notebook), {output_cell}, create_notebook_run_context(output_cell)]
    run_context

  eval_coffeescript_without_input_cell = (notebook, string) ->
    run_without_input_cell notebook, null, CoffeeScriptCell.create_fn string

  run_without_input_cell = (notebook, position, fn) ->
    run_context = create_bare_output_cell_and_context notebook
    insert_cell run_context.output_cell, position
    run_with_context run_context, fn

  create_input_context = (notebook) ->
    context.create_context notebook.base_context

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

  handle_file = (run_context, file, options={}) ->
    if file.type.indexOf('image') < 0
      [prefix..., extension] = file.filename.split '.'
      if extension is 'coffee'
        cell = add_input_cell run_context.notebook, after: run_context.output_cell
        # TODO cell type
        set_cell_value cell, file.content
        if options.run
          run cell
      else if extension is 'md'
        run_without_input_cell run_context.notebook, after: run_context.output_cell, ->
          @md file.content, base_href: file.base_href
      else
        try
          imported = JSON.parse file.content
        catch e
          run_context.fns.error "File #{file.filename} isn't a lead.js notebook:\n#{e}"
          return
        version = imported.lead_js_version
        unless version?
          run_context.fns.error "File #{file.filename} isn't a lead.js notebook"
          return
        import_notebook run_context.notebook, run_context.output_cell, imported, options

  load_file = (run_context, file) ->
    if file.type.indexOf('image') < 0
      reader = new FileReader
      reader.onload = (e) ->
        handle_file run_context,
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

  exports = {
    create_notebook
    input_cell_at_offset
    add_input_cell
    remove_cell
    focus_cell
    eval_coffeescript_without_input_cell
    run_without_input_cell
    set_cell_value

    run: (cell, opts={advance: true}) ->
      output_cell = run cell
      if opts.advance
        new_cell = add_input_cell cell.notebook, after: output_cell, reuse: true
        focus_cell new_cell

    handle_file: handle_file

    save: (cell) ->
      run_without_input_cell cell.notebook, before: cell, -> @fns.notebook.save()

    context_help: (cell, token) ->
      run_without_input_cell cell.notebook, before: cell, ->
        if graphite.has_docs token
          @docs token
        else if cell.context.imported_context_fns[token]?
          @help token

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

  exports
