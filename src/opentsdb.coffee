define (require) ->
  _ = require 'underscore'
  $ = require 'jquery'
  modules = require 'modules'
  http = require 'http'

  opentsdb = modules.create 'opentsdb', ({fn, cmd, settings}) ->
    fn 'tsd', 'Fetches time series data from OpenTSDB', (args...) ->
      @value @async -> opentsdb.tsd args...

    to_metric_string: ({aggregation, metric_name, downsample, tags}) ->
      parts = [aggregation]
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

      result = for name, points of all_series
        target: name
        datapoints: _.sortBy points, ([v, t]) -> t

    data_url: ({time_series, start, end, aggregation, group}) ->
      m = _.map time_series, opentsdb.to_metric_string
      params = {start, end, m, ascii: true}
      base_url = settings.get 'base_url'
      "#{base_url}/q?#{$.param params, true}"

    tsd: (params) ->
      http.get(opentsdb.data_url(params), dataType: 'text')
      .then (txt) -> opentsdb.parse_text_response txt, group
