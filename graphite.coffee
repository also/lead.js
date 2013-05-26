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



