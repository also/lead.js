define (require) ->
  _ = require 'underscore'
  $ = require 'jquery'
  lead = require 'core'
  modules = require 'modules'
  graph = require 'graph'

  {fn, cmd, ops, settings} = modules.create 'graphite'

  graphite =
    ops: ops

    is_pattern: (s) ->
      for c in '*?[{'
        return true if s.indexOf(c) >= 0
      false

    url: (path, params) ->
      query_string = $.param params, true
      base_url = settings.get 'base_url'
      "#{base_url}/#{path}?#{query_string}"

    render_url: (params) -> graphite.url 'render', params

    # returns a promise
    get_data: (params, options) ->
      params.format = 'json'
      deferred = $.ajax
        url: graphite.render_url params
        dataType: 'json'

      deferred.then null, (response) ->
        html = $.parseHTML(response.responseText).filter (n) -> n.nodeType isnt 3
        pre = $(html[0].getElementsByTagName 'pre')
        if pre.length > 0
          # graphite style error message in a pre
          msg = pre.text()
        else
          for n in html
            pre = n.querySelectorAll 'pre.exception_value'
            if pre.length > 0
              msg = pre[0].innerText
              break
        msg

    # returns a promise
    complete: (query) ->
      params =
        query: encodeURIComponent query
        format: 'completer'

      $.ajax
        url: graphite.url 'metrics/find', params
        dataType: 'json'
      .then (response) ->
        parts = query.split('.')
        pattern_parts = parts.map(graphite.is_pattern)
        list = (node.path for node in response.metrics)
        patterned_list = for path in list
          result = for matched, i in path.split('.')
            if pattern_parts[i]
              parts[i]
            else
              matched
          result.join '.'
        _.uniq patterned_list.concat(list)

    args_to_params: ({args, default_options}) ->
      if args.legnth == 0
        # you're doing it wrong
        {}
      if args.length == 1
        arg = args[0]
        targets = arg.targets ? arg.target
        if targets?
          if arg.options
            options = arg.options
          else
            options = _.clone arg
            delete options.targets
            delete options.target
        else
          targets = args[0]
          options = {}
      else
        last = args[args.length - 1]

        if _.isString == 'string' or lead.is_lead_node(last) or _.isArray last
          targets = args
          options = {}
        else
          [targets..., options] = args

      targets = [targets] unless _.isArray targets
      # flatten one level of nested arrays
      targets = Array.prototype.concat.apply [], targets

      params = _.extend {}, default_options, options
      params.target = (lead.to_target_string(target) for target in targets)
      params

    function_docs: {}
    parameter_docs: {}
    parameter_doc_ids: {}

    load_docs: ->
      $.getJSON 'render_api.fjson', (data) =>
        html = $.parseHTML(data.body)[0]
        parameters = html.querySelector 'div#graph-parameters'
        a.remove() for a in parameters.querySelectorAll 'a.headerlink'
        for section in parameters.querySelectorAll 'div.section'
          name = $(section.querySelector 'h3').text()
          @parameter_docs[name] = section
          @parameter_doc_ids[section.id] = name

      $.getJSON 'functions.fjson', (data) =>
        prefix_length = "graphite.render.functions.".length

        html = $.parseHTML(data.body)[0]
        for tag in html.getElementsByTagName 'dt'
          for a in tag.getElementsByTagName 'a'
            a.remove()
          @function_docs[tag.id[prefix_length..]] = tag.parentNode

    has_docs: (name) ->
      @parameter_docs[name]? or @parameter_doc_ids[name]? or @function_docs[name]?


  args_to_params = (args, {default_options, current_options}) ->
    graphite.args_to_params {args, default_options: _.extend({}, default_options, current_options)}

  default_target_command = 'img'

  fn 'q', 'Escapes a Graphite metric query', (targets...) ->
    for t in targets
      unless _.isString t
        throw new TypeError "#{t} is not a string"
    @value new lead.type.q targets.map(String)...

  cmd 'docs', 'Shows the documentation for a graphite function or parameter', (name) ->
    if name?
      name = name.to_js_string() if name.to_js_string?
      name = name._lead_context_fn?.name if name._lead_op?
      dl = graphite.function_docs[name]
      if dl?
        $result = @output()
        pres = dl.getElementsByTagName 'pre'
        examples = []
        for pre in pres
          for line in pre.innerText.split '\n'
            if line.indexOf('&target=') == 0
              examples.push line[8..]
        $result.append dl.cloneNode true
        for example in examples
          @cli.example "#{default_target_command} #{JSON.stringify example}", run: false
      name = graphite.parameter_doc_ids[name] ? name
      div = graphite.parameter_docs[name]
      if div?
        $result = @output()
        docs = $(div.cloneNode true)
        context = @
        docs.find('a').on 'click', (e) ->
          e.preventDefault()
          href = $(this).attr 'href'
          if href[0] is '#'
            context.run "docs '#{decodeURI href[1..]}'"
        $result.append docs
      unless dl? or div?
        @cli.text 'Documentation not found'
    else
      @cli.html '<h3>Functions</h3>'
      names = (name for name of graphite.function_docs)
      names.sort()
      for name in names
        sig = $(graphite.function_docs[name].getElementsByTagName('dt')[0]).text().trim()
        @cli.example "docs #{name}  # #{sig}"

      @cli.html '<h3>Parameters</h3>'
      names = (name for name of graphite.parameter_docs)
      names.sort()
      for name in names
        @cli.example "docs '#{name}'"

  fn 'params', 'Generates the parameters for a Graphite render call', (args...) ->
    result = args_to_params args, @
    @value result

  fn 'url', 'Generates a URL for a Graphite image', (args...) ->
    params = args_to_params args, @
    url = graphite.render_url params
    $a = $ "<a href='#{url}' target='blank'/>"
    $a.text url
    $pre = $ '<pre>'
    $pre.append $a
    @output $pre

  fn 'img', 'Renders a Graphite graph image', (args...) ->
    params = args_to_params args, @
    url = graphite.render_url params
    @async ->
      $img = $ "<img src='#{url}'/>"
      @output $img
      deferred = $.Deferred()
      $img.on 'load', deferred.resolve
      $img.on 'error', deferred.reject

      promise = deferred.promise()
      promise.fail (args...) =>
        @cli.error 'Failed to load image'

  fn 'data', 'Fetches Graphite graph data', (args...) ->
    params = args_to_params args, @
    @value @async ->
      promise = graphite.get_data params
      promise._lead_render = ->
        $result = @output()
        promise.done (response) =>
          for series in response
            $header = $ '<h3>'
            $header.text series.target
            $result.append $header
            $table = $ '<table>'
            for [value, timestamp] in series.datapoints
              time = moment(timestamp * 1000)
              $table.append "<tr><th>#{time.format('MMMM Do YYYY, h:mm:ss a')}</th><td class='cm-number number'>#{value?.toFixed(3) or '(none)'}</td></tr>"
            $result.append $table
        promise.fail (error) =>
          @cli.error error
      promise

  fn 'graph', 'Graphs a Graphite target using d3', (args...) ->
    @async ->
      $result = @output()
      if args[0].pipe?
        promise = args[0]
        # TODO shouldn't need to pass fake first arg
        params = args_to_params([[], args[1..]...], @)
      else
        params = args_to_params args, @
        params.format = 'json'
        promise = graphite.get_data params
      promise.done (response) =>
        graph.draw $result.get(0), response, params
      promise.fail (error) =>
        @cli.error error

  fn 'find', 'Finds named Graphite metrics using a wildcard query', (query) ->
    query_parts = query.split '.'
    @value @async ->
      $result = @output()
      params =
        query: encodeURIComponent query
        format: 'completer'
      promise = $.ajax
        url: graphite.url 'metrics/find', params
        dataType: 'json'
      .then (response) ->
        _.map response.metrics, ({path, name, is_leaf}) -> {path, name, is_leaf: is_leaf == '1'}

      promise._lead_render = ->
        promise.done (metrics) =>
          $ul = $ '<ul class="find-results"/>'
          for node in metrics
            $li = $ '<li class="cm-string"/>'
            text = node.path
            text += '*' unless node.is_leaf
            node_parts = text.split '.'
            for part, i in node_parts
              if i > 0
                $li.append '.'
              $span = $ '<span>'
              $span.addClass 'light' if part == query_parts[i]
              $span.text part
              $li.append $span
            do (text) =>
              $li.on 'click', =>
                if node.is_leaf
                  @run "q(#{JSON.stringify text})"
                else
                  @run "find #{JSON.stringify text}"

            $ul.append $li
          $result.append $ul
      promise

  graphite

