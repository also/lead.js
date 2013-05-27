base_url = 'http://grodan.biz'

lead.graphite =
  url: (path, params) ->
    query_string = $.param params, true
    "#{base_url}/#{path}?#{query_string}"

  render_url: (params) -> lead.graphite.url 'render', params

  get_data: (params, options) ->
    params.format = 'json'
    $.ajax
      url: lead.graphite.render_url params
      dataType: 'json'
      success: options.success
      error: (response) ->
        html = $.parseHTML(response.responseText).filter (n) -> n.nodeType isnt 3
        msg = $(html[0].getElementsByTagName 'pre').text()
        options.error msg

  complete: (query, options) ->
    params = 
      query: encodeURIComponent query
      format: 'completer'

    $.ajax
      url: lead.graphite.url 'metrics/find', params
      dataType: 'json'
      success: options.success

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
          options = $.extend {}, arg
          delete options.targets
          delete options.target
      else
        targets = args[0]
        options = {}
    else
      last = args[args.length - 1]

      if $.type(last) == 'string' or lead.is_lead_node(last) or $.isArray last
        targets = args
        options = {}
      else
        [targets..., options] = args

    targets = [targets] unless $.isArray targets
    # flatten one level of nested arrays
    targets = Array.prototype.concat.apply [], targets

    params = $.extend {}, default_options, options
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

