define (require) ->
  $ = require 'jquery'
  _ = require 'underscore'
  CoffeeScript = require 'coffee-script'
  CodeMirror = require 'cm/codemirror'
  URI = require 'URIjs'
  Bacon = require 'baconjs'
  ed = require 'editor'
  http = require 'http'
  graphite = require 'graphite'
  context = require 'context'
  modules = require 'modules'

  modules.create 'notebook', ({cmd}) ->
    cmd 'save', 'Saves the current notebook to a file', ->
      @output save @input_cell

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

    cmd 'quiet', 'Hides the input cell', ->
      hide_cell @input_cell

    cmd 'clear', 'Clears the notebook', ->
      clear_notebook @notebook


    notebook_content_type = 'application/x-lead-notebook'

    forwards = +1
    backwards = -1

    # predicates for cells
    is_input = (cell) -> cell.type is 'input'
    is_output = (cell) -> cell.type is 'output'
    is_clean = (cell) -> cell.is_clean()
    visible = (cell) -> cell.visible
    identity = (cell) -> true


    init_codemirror = ->
      CodeMirror.keyMap.lead = ed.key_map
      _.extend CodeMirror.commands, ed.commands


    create_notebook = (opts) ->
      $file_picker = $ '<input type="file" id="file" class="file_picker"/>'
      $file_picker.on 'change', (e) ->
        for file in e.target.files
          load_file notebook.opening_run_context, file

        notebook.opening_run_context = null
        # reset the file picker so change is triggered again
        $file_picker.val ''

      $document = $ '<div class="document"/>'
      $document.append $file_picker
      notebook =
        cells: []
        input_number: 1
        output_number: 1
        $document: $document
        $file_picker: $file_picker
        cell_run: new Bacon.Bus
        cell_focused: new Bacon.Bus

      unless is_nodejs?
        scrolls = $(window).asEventStream 'scroll'
        scroll_to = notebook.cell_run.flatMapLatest (input_cell) -> input_cell.output_cell.done.delay(0).takeUntil scrolls
        scroll_to.onValue (output_cell) ->
          $('html, body').scrollTop output_cell.$el.offset().top

      context.create_base_context(opts).then (base_context) ->
        notebook.base_context = base_context
        notebook

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
            run cell
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
      set_cell_value cell, opts.code if opts.code?
      cell

    # run an input cell above the current cell
    eval_coffeescript_before = (current_cell, code) ->
      cell = add_input_cell current_cell.notebook, code: code, before: current_cell
      run cell

    eval_coffeescript_after = (current_cell, code) ->
      cell = add_input_cell current_cell.notebook, code: code, after: current_cell
      run cell

    recompile = (error_marks, editor) ->
      m.clear() for m in error_marks
      editor.clearGutter 'error'
      try
        CoffeeScript.compile editor.getValue()
        []
      catch e
        [ed.add_error_mark editor, e]

    create_input_cell = (notebook) ->
      $el = $ '<div class="cell input"/>'
      $link = $ '<span class="permalink">link</span>'
      $code = $ '<div class="code"/>'
      $el.append $link
      $el.append $code
      $link.on 'click', ->
        eval_coffeescript_after cell.output_cell ? cell, 'permalink'

      editor = ed.create_editor $code.get 0

      cell =
        type: 'input'
        $el: $el
        visible: true
        active: true
        notebook: notebook
        context: create_input_context notebook
        used: false
        editor: editor
        rendered: -> editor.refresh()
        hide: -> $el.hide()
        is_clean: -> editor.getValue() is '' and not @.used

      editor.lead_cell = cell

      changes = ed.as_event_stream editor, 'change'
      # scan changes for the side effect in in recompile
      # we have to subscribe so that the events are sent
      changes.debounce(200).scan([], recompile).onValue ->

      cell

    set_cell_value = (cell, value) ->
      cell.editor.setValue value
      cell.editor.setCursor(line: cell.editor.lineCount() - 1)

    focus_cell = (cell) ->
      cell.editor.focus()
      cell.notebook.cell_focused.push cell

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

    run = (input_cell) ->
      string = input_cell.editor.getValue()
      output_cell = create_output_cell input_cell.notebook
      input_cell.used = true
      remove_cell input_cell.output_cell if input_cell.output_cell?
      insert_cell output_cell, after: input_cell
      input_cell.number = input_cell.notebook.input_number++
      input_cell.$el.attr 'data-cell-number', input_cell.number
      input_cell.output_cell = output_cell

      # TODO cell type
      run_context = context.create_run_context [input_cell.context, {input_cell, output_cell}, create_notebook_run_context input_cell]
      eval_coffeescript_into_output_cell run_context, string
      input_cell.notebook.cell_run.push input_cell
      output_cell

    eval_coffeescript_into_output_cell = (run_context, string) ->
      run_with_context run_context, ->
        context.eval_coffeescript_in_context run_context, string

    run_with_context = (run_context, fn) ->
      output_cell = run_context.output_cell
      has_pending = run_context.pending.map (n) -> n > 0
      # FIXME not sure why this is necessary; seems like a bug in Bacon
      # without it, the skipWhile seems to be ignored
      has_pending.subscribe ->
      # a cell is "done enough" if there were no async tasks,
      # or when the first async task completes
      no_longer_pending = run_context.changes.skipWhile(has_pending)
      output_cell.done = no_longer_pending.take(1).map -> output_cell

      fn()

      output_cell.$el.append context.render run_context

    create_bare_output_cell_and_context = (notebook) ->
      output_cell = create_output_cell notebook
      run_context = context.create_run_context [create_input_context(notebook), {output_cell}, create_notebook_run_context(output_cell)]
      insert_cell output_cell
      run_context

    eval_coffeescript_without_input_cell = (notebook, string) ->
      run_context = create_bare_output_cell_and_context notebook
      eval_coffeescript_into_output_cell run_context, string

    run_without_input_cell = (notebook, fn) ->
      run_context = create_bare_output_cell_and_context notebook
      run_with_context run_context, ->
        context.run_in_context run_context, fn

    create_input_context = (notebook) ->
      context.create_context notebook.base_context

    create_notebook_run_context = (cell) ->
      notebook = cell.notebook
      run_context =
        notebook: notebook
        # TODO rename
        set_code: (code) ->
          # TODO coffeescript
          cell = add_input_cell notebook, code: code, after: run_context.output_cell
          focus_cell cell
        run: (code) ->
          # TODO coffeescript
          cell = add_input_cell notebook, code: code, after: run_context.output_cell
          run cell
        # TODO does it make sense to use output cells here?
        previously_run: -> input_cell_at_offset(cell, -1).editor.getValue()
        export_notebook: -> export_notebook cell
        get_input_value: (number) ->
          get_input_cell_by_number(notebook, number)?.editor.getValue()

    open_file_picker = (run_context) ->
      run_context.notebook.opening_run_context = run_context
      run_context.notebook.$file_picker.trigger 'click'

    handle_file = (run_context, file, options={}) ->
      if file.type.indexOf('image') < 0
        [prefix..., extension] = file.filename.split '.'
        if extension is 'coffee'
          cell = add_input_cell run_context.notebook, code: file.content, after: run_context.output_cell
          if options.run
            run cell
        else if extension is 'md'
          run_without_input_cell run_context.notebook, ->
            @md file.content
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
      link.innerHTML = 'Download Notebook'
      link.href = window.webkitURL.createObjectURL blob
      link.download = 'notebook.lnb'
      link.click()
      link

    exports = {
      create_notebook
      input_cell_at_offset
      init_codemirror
      add_input_cell
      remove_cell
      focus_cell
      eval_coffeescript_without_input_cell
      run_without_input_cell

      run: (cell, opts={advance: true}) ->
        output_cell = run cell
        if opts.advance
          new_cell = add_input_cell cell.notebook, after: output_cell, reuse: true
          focus_cell new_cell

      handle_file: handle_file

      save: (cell) ->
        eval_coffeescript_before cell, 'save'

      context_help: (cell, token) ->
        if graphite.has_docs token
          eval_coffeescript_before cell, "docs '#{token}'"
        else if cell.context.imported_context_fns[token]?
          eval_coffeescript_before cell, "help #{token}"

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
