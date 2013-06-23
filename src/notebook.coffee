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

  init_codemirror = ->
    CodeMirror.keyMap.lead = ed.key_map
    $.extend CodeMirror.commands, ed.commands

  create_notebook = ->
    cells: []
    input_number: 1
    default_options: {}
    $document: $ '<div class="document"/>'

  export_notebook = (current_cell) ->
    lead_js_version: 0
    cells: current_cell.notebook.cells.filter((cell) -> cell != current_cell).map (cell) ->
      type: 'input'
      value: cell.editor.getValue()

  import_notebook = (notebook, imported, options) ->
    for cell in imported.cells
      if cell.type is 'input'
        if options.run
          run_in_available_context cell.value
        else
          add_context notebook, cell.value

  clear_notebook = (notebook) ->
    notebook.$document.empty()
    notebook.cell.slength = 0

  input_cell_at_offset = (cell, offset) ->
    index = cell.notebook.cells.indexOf cell
    cell.notebook.cells[index + offset]

  get_available_input_cell = (notebook) ->
    last = notebook.cells[notebook.cells.length - 1]
    if last?.is_clean()
      return last
    else
      return null

  remove_cell = (cell) ->
    index = cell.notebook.cells.indexOf cell
    cell.$el.remove()
    cell.notebook.cells.splice index, 1

  add_context = (notebook, code='') ->
    cell = get_available_input_cell notebook
    if cell?
      cell.editor.setValue code
    else
      cell = create_input_cell notebook, code
      notebook.$document.append cell.$el
      cell.rendered()
      notebook.cells.push cell

    {editor} = cell
    editor.focus()
    editor.setCursor(line: editor.lineCount() - 1)
    cell

  run_in_available_context = (notebook, code) ->
    add_context(notebook, code).run()
    add_context notebook

  # Add an input cell above the last input cell
  run_in_info_context = (current_cell, code) ->
    cell = create_input_cell current_cell.notebook, code
    current_cell.$el.before cell.$el
    index = notebook.cells.indexOf cell
    cell.rendered()
    current_cell.notebook.cells.splice index, 0, cell
    cell.run code

  create_input_cell = (notebook, code) ->
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
      notebook: notebook
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
        context.input_number = notebook.input_number++
        context.$el.attr 'data-cell-number', context.input_number

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

  get_input_cell_by_number = (notebook, number) ->
    for cell in notebook
      return cell if cell.input_number == number

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

    notebook = input_cell.notebook
    run_context =
      notebook: notebook
      ops: ops
      current_options: {}
      default_options: notebook.default_options
      output: output $el
      success: ->
        scroll_to_result $top
        ignore
      failure: ->
        scroll_to_result $top
        ignore
      set_code: (code) -> add_context notebook, code
      run: (code) -> run_in_available_context notebook, code
      clear_output: -> clear_notebook notebook
      previously_run: -> input_cell_at_offset(input_cell, -1).editor.getValue()
      hide_input: -> remove_cell input_cell
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
        cell = get_input_cell_by_number notebook, number
        cell?.editor.getValue()

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

    $el: $el

  opening_run_context = null

  open_file_picker = (run_context) ->
    opening_run_context = run_context
    $file_picker.trigger 'click'

  handle_file = (run_context, file, options={}) ->
    if file.type.indexOf('image') < 0
      [_..., extension] = file.filename.split '.'
      if extension is 'coffee'
        if options.run
          run_in_available_context run_context.notebook, file.content
        else
          add_context run_context.notebook, file.content
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
        import_notebook run_context.notebook, imported, options

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
        run_in_available_context notebook, rc

      uri = URI location.href
      fragment = uri.fragment()
      if fragment.length > 0 and fragment[0] == '/'
        id = fragment[1..]
        run_in_available_context notebook, "gist #{JSON.stringify id}, run: true; quiet"
      else
        program = if location.search isnt ''
          atob decodeURIComponent location.search[1..]
        else
          'intro'

        run_in_available_context notebook, program

    run: (cell) ->
      cell.run()
      add_context cell.notebook

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
        new_cell.editor.focus()
        true
      else
        false

    cell_value: (cell) ->
      cell.editor.getValue()

    input_cell_at_offset: input_cell_at_offset

  exports
