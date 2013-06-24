define (require) ->
  lead = require 'core'
  ed = require 'editor'
  CoffeeScript = require 'lib/coffee-script'
  graphite = require 'graphite'
  graphite_function_names = require 'functions'
  URI = require 'lib/URI'
  github = require 'github'
  colors = require 'colors'
  ops = require 'ops'

  ignore = new Object

  define_parameters = true

  $file_picker = null

  notebook_content_type = 'application/x-lead-notebook'

  graphite.load_docs()

  forwards = +1
  backwards = -1

  is_input = (cell) -> cell.type is 'input'
  is_output = (cell) -> cell.type is 'output'
  is_clean = (cell) -> cell.is_clean()
  visible = (cell) -> cell.visible
  identity = (cell) -> true

  init_codemirror = ->
    CodeMirror.keyMap.lead = ed.key_map
    $.extend CodeMirror.commands, ed.commands

  create_notebook = ->
    cells: []
    input_number: 1
    output_number: 1
    default_options: {}
    $document: $ '<div class="document"/>'

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

  hide_cell = (cell) ->
    cell.visible = false
    cell.$el.hide()

  insert_cell = (cell, position={}) ->
    if position.before?
      offset = 0
      current_cell = position.before
      current_cell.$el.before cell.$el
    else if position.after?
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
    if opts.after?
      cell = seek opts.after, forwards, is_input
    else if opts.before?
      cell = seek opts.before, backwards, is_input
    unless cell? and is_clean cell
      cell = create_input_cell notebook
      insert_cell cell, opts
    set_cell_value cell, opts.code if opts.code?
    cell

  # Add an input cell above the last input cell
  run_in_info_context = (current_cell, code) ->
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

  bind_cli = (run_context) ->
    bind_op = (op) ->
      bound = (args...) ->
        # if the function returned a value, unwrap it. otherwise, ignore it
        op.fn.apply(run_context, args)?._lead_cli_value ? ignore
      bound._lead_op = op
      bound

    bound_ops = {}
    for k, op of ops
      bound_ops[k] = bind_op op

    if define_parameters
      for k of graphite.parameter_docs
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
    bound_ops

  create_output_cell = (notebook) ->
    number = notebook.output_number++

    cell =
      type: 'output'
      $el: $ '<div class="cell output clean"/>'
      notebook: notebook
      rendered: ->
      number: number

    cell.$el.attr 'data-cell-number', cell.number
    cell

  run = (input_cell, string) ->
    output_cell = create_output_cell input_cell.notebook
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
        $target.removeClass 'clean'
        $item = $ '<div class="item"/>'
        if output?
          $item.append output
        $target.append $item
        $item

    notebook = input_cell.notebook
    run_context =
      cell: output_cell
      notebook: notebook
      ops: ops
      current_options: {}
      default_options: notebook.default_options
      output: output output_cell.$el
      success: ->
        scroll_to_result $top
        ignore
      failure: ->
        scroll_to_result $top
        ignore
      set_code: (code) ->
        cell = add_input_cell notebook, code: code, after: run_context.cell
        focus_cell cell
      run: (code) ->
        cell = add_input_cell notebook, code: code, after: run_context.cell
        cell.run()
      clear_output: -> clear_notebook notebook
      previously_run: -> input_cell_at_offset(input_cell, -1).editor.getValue()
      hide_input: -> hide_cell input_cell
      value: (value) -> _lead_cli_value: value
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
            scroll_to_result $top
          failure: ->
            $item.attr 'data-async-status', "failed in #{duration()}"
            scroll_to_result $top
        nested_context.cli = bind_cli nested_context
        fn.call(nested_context)

    run_context.cli = cli = bind_cli run_context

    functions = {}
    vars = lead: {github, graphite, colors}

    handle_exception = (e, compiled) ->
      cli.error printStackTrace({e}).join('\n')
      cli.text 'Compiled JavaScript:'
      cli.source 'javascript', compiled

    error = (message) ->
      $pre = $ '<pre class="error"/>'
      $pre.text message
      run_context.output $pre
      run_context.failure()

    lead.define_functions functions, graphite_function_names
    try
      compiled = CoffeeScript.compile(string, bare: true) + "\n//@ sourceURL=console-coffeescript.js"
    catch e
      if e instanceof SyntaxError
        error "Syntax Error: #{e.message} at #{e.location.first_line + 1}:#{e.location.first_column + 1}"
      else
        handle_exception e, compiled

    if compiled?
      try
        `with (cli) { with (functions) { with (vars) {`
        result = eval compiled
        `}}}`
        unless result == ignore
          if result?._lead_op?
            result._lead_op.cli_fn.apply(run_context)
          else if lead.is_lead_node result
            lead_string = lead.to_string result
            if $.type(result) == 'function'
              cli.text "#{lead_string} is a Graphite function"
              run_in_info_context input_cell, "docs #{result.values[0]}"
            else
              cli.text "What do you want to do with #{lead_string}?"
              for f in ['data', 'graph', 'img', 'url']
                cli.example "#{f} #{result.to_js_string()}"
          else
            cli.object result
      catch e
        handle_exception e, compiled

    output_cell

  opening_run_context = null

  open_file_picker = (run_context) ->
    opening_run_context = run_context
    $file_picker.trigger 'click'

  handle_file = (run_context, file, options={}) ->
    if file.type.indexOf('image') < 0
      [_..., extension] = file.filename.split '.'
      if extension is 'coffee'
        cell = add_input_cell run_context.notebook, code: file.content, after: run_context.cell
        if options.run
          cell.run()
      else
        try
          imported = JSON.parse file.content
        catch e
          run_context.cli.error "File #{file.filename} isn't a lead.js notebook:\n#{e}"
          return
        version = imported.lead_js_version
        unless version?
          run_context.cli.error "File #{file.filename} isn't a lead.js notebook"
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

  exports =
    init_editor: ->
      init_codemirror()
      $document = $ '#document'
      $file_picker = $ '#file'

      notebook = create_notebook()
      $document.append notebook.$document

      $file_picker.on 'change', (e) ->
        for file in e.target.files
          load_file opening_run_context, file

        opening_run_context = null
        # reset the file picker so change is triggered again
        $file_picker.val ''

      rc = localStorage.lead_rc
      if rc?
        add_input_cell(notebook, code: rc).run()

      uri = URI location.href
      fragment = uri.fragment()
      if fragment.length > 0 and fragment[0] == '/'
        id = fragment[1..]
        program = "gist #{JSON.stringify id}, run: true; quiet"
      else
        program = if location.search isnt ''
          atob decodeURIComponent location.search[1..]
        else
          'intro'

      add_input_cell(notebook, code: program).run()
      add_input_cell notebook

    run: (cell) ->
      output_cell = cell.run()
      new_cell = add_input_cell cell.notebook, after: output_cell
      focus_cell new_cell

    handle_file: handle_file

    save: (cell) ->
      run_in_info_context cell, 'save'

    context_help: (cell, token) ->
      if graphite.has_docs token
        run_in_info_context cell, "docs '#{token}'"
      else if ops[token]?
        run_in_info_context cell, "help #{token}"

    move_focus: (cell, offset) ->
      new_cell = input_cell_at_offset cell, offset
      if new_cell?
        focus_cell new_cell
        true
      else
        false

    cell_value: (cell) ->
      cell.editor.getValue()

    input_cell_at_offset: input_cell_at_offset

  exports
