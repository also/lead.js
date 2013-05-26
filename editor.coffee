_lead_finished = new Object

default_options = {}

default_target_command = 'img'

previously_run = null

graphite_function_docs = {}
graphite_parameter_docs = {}
graphite_parameter_doc_ids = {}
$.getJSON 'render_api.fjson', (data) ->
  html = $.parseHTML(data.body)[0]
  parameters = html.querySelector 'div#graph-parameters'
  a.remove() for a in parameters.querySelectorAll 'a.headerlink'
  for section in parameters.querySelectorAll 'div.section'
    name = $(section.querySelector 'h3').text()
    graphite_parameter_docs[name] = section
    graphite_parameter_doc_ids[section.id] = name

has_docs = (name) ->
  graphite_parameter_docs[name]? or graphite_parameter_doc_ids[name]? or graphite_function_docs[name]?

$.getJSON 'functions.fjson', (data) ->
  prefix_length = "graphite.render.functions.".length

  html = $.parseHTML(data.body)[0]
  for tag in html.getElementsByTagName 'dt'
    for a in tag.getElementsByTagName 'a'
      a.remove()
    graphite_function_docs[tag.id[prefix_length..]] = tag.parentNode

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
    list = (k for k of graphite_function_docs)
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
    s = token.string
    next_token = token_after cm, token, cur.line
    list = []
    for k of create_ns()
      if k.indexOf(s) is 0
        list.push k
    for k of graphite_function_docs
      if k.indexOf(s) is 0
        list.push k
    for k of graphite_parameter_docs
      if k.indexOf(s) is 0
        suggestion = k
        suggestion += ': ' unless next_token?.string is ':'
        list.push suggestion
    showHints
      list: list
      from: CodeMirror.Pos cur.line, token.start
      to: CodeMirror.Pos cur.line, token.end

window.init_editor = ->
  CodeMirror.commands.run = (cm) ->
    setTimeout(-> run cm.getValue(), 1)

  CodeMirror.commands.contextHelp = (cm) ->
    cur = editor.getCursor()
    token = cm.getTokenAt(cur)
    if has_docs token.string
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
    extraKeys:
      'Shift-Enter': 'run'
      'F1': 'contextHelp'
      'Ctrl-Space': 'suggest'

  $output.css 'padding-bottom': ($code.height() + 60) + 'px'
  editor.on 'viewportChange', ->
    $output.css 'padding-bottom': ($code.height() + 60 ) + 'px'

  scroll_to_result = ($result)->
    top = if $result?
      $result.offset().top
    else
      $(document).height()

    setTimeout ->
      $('html, body').scrollTop top
    , 10

  window.create_ns = (context) ->
    current_options = {}

    args_to_params = (args) ->
      is_target = (x) ->
        $.type(x) == 'string' or lead.is_lead_node x

      if args.legnth == 0
        # you're doing it wrong
        {}
      if args.length == 1
        arg = args[0]
        if arg.targets
          targets = arg.targets
          if arg.options
            options = arg.options
          else
            options = arg
            delete options.targets
        else
          targets = args[0]
          options = {}
      else
        last = args[args.length - 1]

        if is_target last
          targets = args
          options = {}
        else
          [targets..., options] = args

      targets = [targets] unless $.isArray targets

      params = $.extend {}, default_options, current_options, options
      params.target = (lead.to_target_string(target) for target in targets)
      params

    cmd = (doc, wrapped) ->
      wrapped._lead_cli_fn = wrapped
      wrapped._lead_doc = doc
      wrapped

    fn = (doc, wrapped) ->
      wrapped._lead_cli_fn = ->
        cli.text "Did you forget to call a function? \"#{wrapped._lead_cli_name}\" must be called with arguments."
        run "help #{wrapped._lead_cli_name}"
      wrapped._lead_doc = doc
      wrapped

    output_object = (o) ->
      $pre = $ '<pre>'
      s = JSON.stringify(o, null, '  ') or new String o
      CodeMirror.runMode s, {name: 'javascript', json: true}, $pre.get(0)
      context.$result.append $pre
      context.success()
      _lead_finished

    json = (url) ->

    cli =
      help:
        cmd 'Shows this help', (cmd) ->
          if cmd?
            cmd = cmd._lead_cli_name ? cmd
            doc = cli[cmd]?._lead_doc
            if doc
              cli.pre "#{cmd}\n    #{doc}"
            else
              cli.pre "#{cmd} is not a command."
          else
            commands = ("  #{cmd}:\n    #{cli[cmd]._lead_doc}" for cmd in cli_commands).join('\n\n')
            cli.pre "Check out these awesome built-in functions:\n\n#{commands}"

      object:
        fn 'Prints an object as JSON', output_object

      text:
        fn 'Prints text', (string) ->
          $pre = $ '<p>'
          $pre.text string
          context.$result.append $pre
          context.success()

      pre:
        fn 'Prints preformatted text', (string) ->
          $pre = $ '<pre>'
          $pre.text string
          context.$result.append $pre
          context.success()

      html:
        fn 'Adds some HTML', (html) ->
          context.$result.append html
          context.success()

      example:
        fn 'Makes a clickable code example', (string, opts) ->
          $pre = $ '<pre class="example">'
          CodeMirror.runMode string, 'coffeescript', $pre.get(0)
          $pre.on 'click', ->
            if opts?.run ? true
              run string
            else
              set_code string
          context.$result.append $pre
          context.success()

      source:
        fn 'Shows source code with syntax highlighting', (language, string) ->
          $pre = $ '<pre>'
          CodeMirror.runMode string, 'javascript', $pre.get(0)
          context.$result.append $pre
          context.success()


      intro:
        cmd 'Shows the intro message', ->
          cli.text "Welcome to lead.js!\n\nPress Shift+Enter to execute the CoffeeScript in the console. Try running"
          cli.example "find '*'"
          cli.text 'Look at'
          cli.example 'docs'
          cli.text 'to see what you can do with Graphite.'

      docs:
        cmd 'Shows the documentation for a graphite function or parameter', (name) ->
          if name?
            name = name.to_js_string() if name.to_js_string?
            dl = graphite_function_docs[name]
            if dl?
              pres = dl.getElementsByTagName 'pre'
              examples = []
              for pre in pres
                for line in pre.innerText.split '\n'
                  if line.indexOf('&target=') == 0
                    examples.push line[8..]
              context.$result.append dl.cloneNode true
              for example in examples
                cli.example "#{default_target_command} #{JSON.stringify example}", run: false
            else
              name = graphite_parameter_doc_ids[name] ? name
              div = graphite_parameter_docs[name]
              if div?
                docs = $(div.cloneNode true)
                docs.find('a').on 'click', (e) ->
                  e.preventDefault()
                  href = $(this).attr 'href'
                  if href[0] is '#'
                    run "docs '#{decodeURI href[1..]}'"
                context.$result.append docs
              else
                cli.text 'Documentation not found'
            context.success()
          else
            cli.html '<h3>Functions</h3>'
            names = (name for name of graphite_function_docs)
            names.sort()
            for name in names
              sig = $(graphite_function_docs[name].getElementsByTagName('dt')[0]).text().trim()
              cli.example "docs #{name}  # #{sig}"

            cli.html '<h3>Parameters</h3>'
            names = (name for name of graphite_parameter_docs)
            names.sort()
            for name in names
              cli.example "docs '#{name}'"
            context.success()

      clear:
        cmd 'Clears the screen', ->
          $output.empty()
          context.success()

      options:
        fn 'Gets or sets options', (options) ->
          if options?
            $.extend current_options, options
          current_options


      defaults:
        cmd 'Gets or sets default options', (options) ->
          if options?
            $.extend default_options, options
          cli.object default_options

      url:
        fn 'Generates a URL for a Graphite image', (args...) ->
          params = args_to_params args
          url = lead.graphite.render_url params
          $a = $ "<a href='#{url}' target='blank'/>"
          $a.text url
          $pre = $ '<pre>'
          $pre.append $a
          context.$result.append($pre)
          context.success()

      img:
        fn 'Renders a Graphite graph image', (args...) ->
          params = args_to_params args
          url = lead.graphite.render_url params
          $img = $ "<img src='#{url}'/>"
          $img.on 'load', -> context.success()
          $img.on 'error', ->
            cli.text 'Failed to load image'
            context.failure()
          context.$result.append($img)
          _lead_finished

      data:
        fn 'Fetches Graphite graph data', (args...) ->
          params = args_to_params args
          lead.graphite.get_data params,
            success: (response) ->
              for series in response
                $header = $ '<h3>'
                $header.text series.target
                context.$result.append $header
                $table = $ '<table>'
                for [value, timestamp] in series.datapoints
                  time = moment(timestamp * 1000)
                  $table.append "<tr><th>#{time.format('MMMM Do YYYY, h:mm:ss a')}</th><td class='cm-number number'>#{value?.toFixed(3) or '(none)'}</td></tr>"
                context.$result.append $table
                context.success()
          _lead_finished

      graph:
        fn 'Graphs a Graphite target using d3', (args...) ->
          params = args_to_params args
          params.format = 'json'
          lead.graphite.get_data params,
            success: (response) ->
              lead.graph.draw context.$result.get(0), response, params
              context.success()
          _lead_finished

      find:
        fn 'Finds named Graphite metrics using a wildcard query', (query) ->
          query_parts = query.split '.'
          lead.graphite.complete query,
            success: (response) ->
              $ul = $ '<ul class="find-results"/>'
              for node in response.metrics
                $li = $ '<li class="cm-string"/>'
                text = node.path
                text += '*' if node.is_leaf == '0'
                node_parts = text.split '.'
                for part, i in node_parts
                  if i > 0
                    $li.append '.'
                  $span = $ '<span>'
                  $span.addClass 'light' if part == query_parts[i]
                  $span.text part
                  $li.append $span
                do (text) ->
                  $li.on 'click', ->
                    if node.is_leaf == '0'
                      run "find #{JSON.stringify text}"
                    else
                      run "q(#{JSON.stringify text})"
                $ul.append $li
              context.$result.append $ul
              context.success()
          _lead_finished

      permalink:
        cmd 'Create a link to the previously run statement', ->
          a = document.createElement 'a'
          a.href = location.href
          a.search = '?' + encodeURIComponent btoa previously_run if previously_run?
          a.innerText = a.href
          context.$result.append a
          context.success()

      q: do ->
        result = (targets...) ->
          for t in targets
            unless $.type(t) is 'string'
              throw new TypeError "#{t} is not a string"
          new lead.type.q targets.map(String)...
        result._lead_doc = 'Escapes a Graphite metric query'
        result

    cli_commands = for k, v of cli
      v._lead_cli_name = k
    cli_commands.sort()

    cli

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
    context =
      $result: $result
      success: ->
        scroll_to_result $entry
        _lead_finished
      failure: ->
        scroll_to_result $entry
        _lead_finished

    ns = create_ns context
    functions = {}

    handle_exception = (e, compiled) ->
      error printStackTrace({e}).join('\n')
      ns.text 'Compiled JavaScript:'
      ns.source 'javascript', compiled

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
        `with (ns) { with (functions) {`
        result = eval compiled
        `}}`
        unless result == _lead_finished
          if result?._lead_cli_fn
            result._lead_cli_fn()
          else if lead.is_lead_node result
            lead_string = lead.to_string result
            if $.type(result) == 'function'
              ns.text "#{lead_string} is a Graphite function"
              ns.docs result
            else
              ns.text "What do you want to do with #{lead_string}?"
              for f in ['data', 'graph', 'img', 'url']
                ns.example "#{f} #{result.to_js_string()}"
          else
            ns.object result
        previously_run = string
      catch e
        handle_exception e, compiled

    $entry.append $result

  if location.search isnt ''
    run atob decodeURIComponent location.search[1..]
  else
    run 'intro'
