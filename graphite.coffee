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

  complete: (query, options) ->
    params = 
      query: encodeURIComponent query
      format: 'completer'

    $.ajax
      url: lead.graphite.url 'metrics/find', params
      dataType: 'json'
      success: options.success

  args_to_params: ({args, default_options}) ->
    is_target = (x) ->
      $.type(x) == 'string' or lead.is_lead_node x

    if args.legnth == 0
      # you're doing it wrong
      {}
    if args.length == 1
      arg = args[0]
      if arg.targets?
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

    params = $.extend {}, default_options, options
    params.target = (lead.to_target_string(target) for target in targets)
    params

