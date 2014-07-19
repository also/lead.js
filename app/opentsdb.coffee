_ = require 'underscore'
$ = require 'jquery'
Q = require 'q'
Html = require './html'
modules = require './modules'
http = require './http'

opentsdb = modules.export exports, 'opentsdb', ({fn, cmd, settings}) ->
  fn 'tsd', 'Fetches time series data from OpenTSDB', (args...) ->
    @value opentsdb.tsd args...

  to_metric_string: (time_series) ->
    if _.isString time_series
      time_series = metric_name: time_series
    {aggregation, metric_name, downsample, tags, rate} = time_series
    parts = [aggregation ? 'sum']
    parts.push 'rate' if rate
    parts.push "#{downsample.period}-#{downsample.aggregation}" if downsample
    parts.push metric_name + '{' + _.map(tags, (tagv, tagk) -> "#{tagk}=#{tagv}").join(',') + '}'
    parts.join ':'

  group_by_name_and_tags: ({metric_name, tags}) ->
    "#{metric_name}{#{tags.join(',')}}"

  parse_text_response: (txt, group) ->
    all_series = {}
    group ?= opentsdb.group_by_name_and_tags

    for line in txt.split '\n'
      unless line == ''
        [metric_name, time, value, tags...] = line.split ' '
        name = group {metric_name, tags}
        points = all_series[name]
        unless points
          points = []
          all_series[name] = points
        points.push [parseInt(value, 10), parseInt(time, 10)]

    for name, points of all_series
      target: name
      datapoints: _.sortBy points, ([v, t]) -> t

  parse_error_response: (response) ->
    doc = Html.parse_document response.responseText
    blockquote = doc.querySelector 'blockquote'
    title = blockquote.querySelector('h1').innerText
    message = blockquote.querySelector('blockquote').innerText
    "#{title}: #{message}"

  data_url: ({time_series, start, end, aggregation, group}) ->
    base_url = settings.get 'base_url'
    if not base_url?
      throw new Error 'OpenTSDB base_url not set'
    start ?= '1d-ago'
    m = _.map time_series, opentsdb.to_metric_string
    params = {start, end, m, ascii: true}
    "#{base_url}/q?#{$.param params, true}"

  tsd: (params) ->
    http.get(opentsdb.data_url(params), dataType: 'text')
    .then(
      (txt) -> opentsdb.parse_text_response txt, params.group
      # TODO error handling
      (response) -> Q.reject opentsdb.parse_error_response response
    )
