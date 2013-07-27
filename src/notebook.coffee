define (require) ->
  $ = require 'jquery'
  _ = require 'underscore'
  CoffeeScript = require 'lib/coffee-script'
  lead = require 'core'
  ed = require 'editor'
  graphite = require 'graphite'
  context = require 'context'

  define_parameters = true

  # FIXME needs to happen after graphite docs have loaded
  ###
  if define_parameters
    for k of graphite.parameter_docs
      do (k) ->
        fn = (value) ->
          if value?
            @current_options[k] = value
          else
            @value @current_options[k] ? @default_options[k]

        all_context_fns[k] =
          name: k
          fn: fn
          cli_fn: ->
            @fns.object @fns[k]()
  ###

  notebook_content_type = 'application/x-lead-notebook'

  forwards = +1
  backwards = -1

  # predicates for cells
  is_input = (cell) -> cell.type is 'input'
  is_output = (cell) -> cell.type is 'output'
  is_clean = (cell) -> cell.is_clean()
  visible = (cell) -> cell.visible
  identity = (cell) -> true


  available_context_fns = (notebook) ->
    notebook.context_fns


  init_codemirror = ->
    CodeMirror.keyMap.lead = ed.key_map
    _.extend CodeMirror.commands, ed.commands


  create_notebook = (defaults) ->
    $file_picker = $ '<input type="file" id="file" class="file_picker"/>'
    $file_picker.on 'change', (e) ->
      for file in e.target.files
        load_file notebook.opening_run_context, file

      notebook.opening_run_context = null
      # reset the file picker so change is triggered again
      $file_picker.val ''

    $document = $ '<div class="document"/>'
    $document.append $file_picker

    notebook = _.extend {}, defaults,
      cells: []
      input_number: 1
      output_number: 1
      default_options: {}
      $document: $document
      $file_picker: $file_picker

  export_notebook = (current_cell) ->
    lead_js_version: 0
    cells: current_cell.notebook.cells.filter((cell) -> cell != current_cell and is_input cell).map (cell) ->
      type: 'input'
      value: cell.editor.getValue()

  import_notebook = (notebook, cell, imported, options) ->
    for imported_cell in imported.cells
      if imported_cell.type is 'input'
        cell = add_input_cell notebook, code: imported_cell.value, after: cell
        if options.run
          cell.run()
    notebook

  clear_notebook = (notebook) ->
    notebook.$document.empty()
    for cell in notebook.cells
      cell.active = false
    notebook.cells.length = 0


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
    cell.$el.remove()
    cell.notebook.cells.splice index, 1
    cell.active = false

  hide_cell = (cell) ->
    cell.visible = false
    cell.$el.hide()

  insert_cell = (cell, position={}) ->
    if position.before?.active
      offset = 0
      current_cell = position.before
      current_cell.$el.before cell.$el
    else if position.after?.active
      offset = 1
      current_cell = position.after
      current_cell.$el.after cell.$el
    else
      cell.notebook.$document.append cell.$el
      cell.notebook.cells.push cell
      cell.rendered()
      return

    index = cell_index current_cell
    current_cell.notebook.cells.splice index + offset, 0, cell

    cell.rendered()

  add_input_cell = (notebook, opts={}) ->
    if opts.reuse
      if opts.after?
        cell = seek opts.after, forwards, (cell) -> is_input(cell) and visible(cell)
      else if opts.before?
        cell = seek opts.before, backwards, (cell) -> is_input(cell) and visible(cell)
    unless cell? and is_clean cell
      cell = create_input_cell notebook
      insert_cell cell, opts
    set_cell_value cell, opts.code if opts.code?
    cell

  # run an input cell above the current cell
  run_before = (current_cell, code) ->
    cell = add_input_cell current_cell.notebook, code: code, before: current_cell
    cell.run()

  run_after = (current_cell, code) ->
    cell = add_input_cell current_cell.notebook, code: code, after: current_cell
    cell.run()

  create_input_cell = (notebook) ->
    $el = $ '<div class="cell input"/>'
    $code = $ '<div class="code"/>'
    $el.append $code

    editor = CodeMirror $code.get(0),
      value: ''
      mode: 'coffeescript'
      keyMap: 'lead'
      tabSize: 2
      viewportMargin: Infinity
      gutters: ['error']

    editor.setCursor(line: editor.lineCount() - 1)

    cell =
      type: 'input'
      $el: $el
      visible: true
      active: true
      notebook: notebook
      used: false
      editor: editor
      rendered: -> editor.refresh()
      hide: -> $el.hide()
      is_clean: -> editor.getValue() is '' and not @.used
      run: ->
        cell.used = true
        remove_cell cell.output_cell if cell.output_cell?
        cell.output_cell = run cell, editor.getValue()
        insert_cell cell.output_cell, after: cell
        cell.number = notebook.input_number++
        cell.$el.attr 'data-cell-number', cell.number
        cell.output_cell

    editor.lead_cell = cell

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

    cell

  set_cell_value = (cell, value) ->
    cell.editor.setValue value
    cell.editor.setCursor(line: cell.editor.lineCount() - 1)

  focus_cell = (cell) ->
    cell.editor.focus()

  create_output_cell = (notebook) ->
    number = notebook.output_number++

    cell =
      type: 'output'
      $el: $ '<div class="cell output clean"/>'
      visible: true
      active: true
      notebook: notebook
      rendered: ->
      number: number

    cell.$el.attr 'data-cell-number', cell.number
    cell

  run = (input_cell, string) ->
    output_cell = create_output_cell input_cell.notebook

    run_context = context.create_run_context output_cell.$el,
      extra_contexts: [create_notebook_run_context input_cell]
      vars: input_cell.notebook.vars
      function_names: input_cell.notebook.function_names
      context_fns: available_context_fns input_cell.notebook

    run_in_context run_context, string

    run_context.scroll_to_top()

    output_cell

  create_notebook_run_context = (input_cell, output_cell) ->
    notebook = input_cell.notebook
    run_context =
      notebook: notebook
      cell: output_cell
      input_cell: input_cell
      default_options: notebook.default_options
      set_code: (code) ->
        cell = add_input_cell notebook, code: code, after: run_context.cell
        focus_cell cell
      run: (code) ->
        cell = add_input_cell notebook, code: code, after: run_context.cell
        cell.run()
      clear_output: -> clear_notebook notebook
      previously_run: -> input_cell_at_offset(input_cell, -1).editor.getValue()
      hide_input: -> hide_cell input_cell
      open_file: -> open_file_picker run_context
      export_notebook: -> export_notebook input_cell
      save: ->
        text = JSON.stringify export_notebook input_cell
        blob = new Blob [text], type: notebook_content_type
        link = document.createElement 'a'
        link.innerHTML = 'Download Notebook'
        link.href = window.webkitURL.createObjectURL blob
        link.download = 'notebook.lnb'
        link.click()
        @output link
      get_input_value: (number) ->
        get_input_cell_by_number(notebook, number)?.editor.getValue()

  run_in_context = (run_context, string) ->
    try
      compiled = CoffeeScript.compile(string, bare: true) + "\n//@ sourceURL=console-coffeescript.js"
    catch e
      if e instanceof SyntaxError
        run_context.error "Syntax Error: #{e.message} at #{e.location.first_line + 1}:#{e.location.first_column + 1}"
      else
        run_context.handle_exception e, compiled

    if compiled?
      try
        `with (run_context.fns) { with (run_context.functions) { with (run_context.vars) {`
        result = eval compiled
        `}}}`
        run_context.display_object result
      catch e
        run_context.handle_exception e, compiled

  open_file_picker = (run_context) ->
    run_context.notebook.opening_run_context = run_context
    run_context.notebook.$file_picker.trigger 'click'

  handle_file = (run_context, file, options={}) ->
    if file.type.indexOf('image') < 0
      [prefix..., extension] = file.filename.split '.'
      if extension is 'coffee'
        cell = add_input_cell run_context.notebook, code: file.content, after: run_context.cell
        if options.run
          cell.run()
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
        import_notebook run_context.notebook, run_context.cell, imported, options

  load_file = (run_context, file) ->
    if file.type.indexOf('image') < 0
      reader = new FileReader
      reader.onload = (e) ->
        handle_file run_context,
          filename: file.name
          content: e.target.result
          type: file.type

      reader.readAsText file

  exports = {
    create_notebook
    available_context_fns
    input_cell_at_offset
    init_codemirror
    add_input_cell
    remove_cell
    focus_cell

    run_cell: (cell) ->
      cell.run()

    run: (cell, opts={advance: true}) ->
      output_cell = cell.run()
      if opts.advance
        new_cell = add_input_cell cell.notebook, after: output_cell, reuse: true
        focus_cell new_cell

    handle_file: handle_file

    save: (cell) ->
      run_before cell, 'save'

    context_help: (cell, token) ->
      if graphite.has_docs token
        run_before cell, "docs '#{token}'"
      else if available_context_fns(cell.notebook)[token]?
        run_before cell, "help #{token}"

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
