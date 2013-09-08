define (require) ->
  _ = require 'underscore'
  $ = require 'jquery'
  bacon = require 'bacon'
  Q = require 'q'
  moment = require 'moment'
  dsl = require 'dsl'
  modules = require 'modules'
  function_names = require 'functions'
  http = require 'http'
  docs = require 'graphite_docs'

  graphite = modules.create 'graphite', ({fn, cmd, settings}) ->
    args_to_params = (context, args) ->
      graphite.args_to_params {args, default_options: context.options()}

    default_target_command = 'img'

    fn 'q', 'Escapes a Graphite metric query', (targets...) ->
      for t in targets
        unless _.isString t
          throw new TypeError "#{t} is not a string"
      @value new dsl.type.q targets.map(String)...

    cmd 'docs', 'Shows the documentation for a graphite function or parameter', (name) ->
      if name?
        name = name.to_js_string() if name.to_js_string?
        name = name._lead_context_fn?.name if name._lead_op?
        function_docs = docs.function_docs[name]
        if function_docs?
          $result = @output()
          $result.append function_docs.docs
          for example in function_docs.examples
            @example "#{default_target_command} #{JSON.stringify example}", run: false
        name = docs.parameter_doc_ids[name] ? name
        parameter_docs = docs.parameter_docs[name]
        if parameter_docs?
          $result = @output()
          $docs = $(parameter_docs)
          context = @
          $docs.find('a').on 'click', (e) ->
            e.preventDefault()
            href = $(this).attr 'href'
            if href[0] is '#'
              context.run "docs '#{decodeURI href[1..]}'"
          $result.append $docs
        unless function_docs? or parameter_docs?
          @text 'Documentation not found'
      else
        @html '<h3>Functions</h3>'
        names = (name for name of docs.function_docs)
        names.sort()
        for name in names
          item = docs.function_docs[name]
          @example "docs #{name}  # #{item.signature}"

        @html '<h3>Parameters</h3>'
        names = (name for name of docs.parameter_docs)
        names.sort()
        for name in names
          @example "docs '#{name}'"

    fn 'params', 'Generates the parameters for a Graphite render call', (args...) ->
      result = args_to_params @, args
      @value result

    fn 'url', 'Generates a URL for a Graphite image', (args...) ->
      params = args_to_params @, args
      url = graphite.render_url params
      $a = $ "<a href='#{url}' target='blank'/>"
      $a.text url
      $pre = $ '<pre>'
      $pre.append $a
      @output $pre

    fn 'img', 'Renders a Graphite graph image', (args...) ->
      params = args_to_params @, args
      url = graphite.render_url params
      @async ->
        $img = $ "<img src='#{url}'/>"
        @output $img
        deferred = $.Deferred()
        $img.on 'load', deferred.resolve
        $img.on 'error', deferred.reject

        promise = deferred.promise()
        promise.fail (args...) =>
          @error 'Failed to load image'

    fn 'data', 'Fetches Graphite graph data', (args...) ->
      params = args_to_params @, args
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
            @error error
        promise

    fn 'graph', 'Graphs Graphite data', (args...) ->
      params = Bacon.constant(args).map(args_to_params, @)
      data = params.map(graphite.get_data).flatMapLatest Bacon.fromPromise
      @graph.graph data, params

    fn 'browser', 'Browse Graphite metrics using a wildcard query', (query) ->
      finder = @graphite.find query
      finder.clicks.onValue (node) =>
        if node.is_leaf
          @run "q(#{JSON.stringify node.path})"
        else
          @run "browser #{JSON.stringify node.path + '*'}"
      @render finder

    fn 'find', 'Finds Graphite metrics', (query) ->
      @value @async ->
        $result = @output()
        promise = graphite.find query

        promise._lead_render = ->
          promise.done ({query, result}) =>
            query_parts = query.split '.'
            $ul = $ '<ul class="find-results"/>'
            for node in result
              $li = $ '<li class="cm-string"/>'
              $li.data 'node', node
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

              promise.clicks.plug $li.asEventStream('click').map (e) -> $(e.target).closest('li').data('node')

              $ul.append $li
            $result.append $ul

        promise.clicks = new Bacon.Bus
        promise

    context_vars: -> dsl.define_functions {}, function_names

    init: ->
      # TODO there's no way for this to be set by the time we get here
      if settings.get 'define_parameters'
        _.map docs.parameter_docs, (v, k) ->
          fn k, "Gets or sets Graphite parameter #{k}", (value) ->
            if value?
              @current_options[k] = value
            else
              @value @current_options[k] ? @default_options[k]

    is_pattern: (s) ->
      for c in '*?[{'
        return true if s.indexOf(c) >= 0
      false

    url: (path, params) ->
      query_string = $.param params, true
      base_url = settings.get 'base_url'
      "#{base_url}/#{path}?#{query_string}"

    render_url: (params) -> graphite.url 'render', params

    parse_error_response: (response) ->
      return 'request failed' unless response.responseText?
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

    parse_find_response: (query, response) ->
      parts = query.split('.')
      pattern_parts = parts.map(graphite.is_pattern)
      list = (node.path for node in response)
      patterned_list = for path in list
        result = for matched, i in path.split('.')
          if pattern_parts[i]
            parts[i]
          else
            matched
        result.join '.'
      _.uniq patterned_list.concat(list)

    # returns a promise
    get_data: (params) ->
      params.format = 'json'
      deferred = http.get graphite.render_url params

      deferred.then null, graphite.parse_error_response

    # returns a promise
    complete: (query) ->
      graphite.find(query)
      .then ({query, result}) ->
        graphite.parse_find_response query, result

    find: (query) ->
      params =
        query: encodeURIComponent query
        format: 'completer'
      http.get(graphite.url 'metrics/find', params)
      .then (response) ->
        result = _.map response.metrics, ({path, name, is_leaf}) -> {path, name, is_leaf: is_leaf == '1'}
        {query, result}

    suggest_keys: (s) ->
      _.filter _.keys(docs.parameter_docs), (k) -> k.indexOf(s) is 0

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

        if _.isString == 'string' or dsl.is_dsl_node(last) or _.isArray last
          targets = args
          options = {}
        else
          [targets..., options] = args

      targets = [targets] unless _.isArray targets
      # flatten one level of nested arrays
      targets = Array.prototype.concat.apply [], targets

      params = _.extend {}, default_options, options
      params.target = (dsl.to_target_string(target) for target in targets)
      params

    has_docs: (name) ->
      docs.parameter_docs[name]? or docs.parameter_doc_ids[name]? or docs.function_docs[name]?

  graphite.suggest_strings = graphite.complete

  graphite

