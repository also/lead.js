define (require) ->
  moment = require 'moment'
  _ = require 'underscore'
  modules = require 'modules'

  time = modules.create 'time', ({fn}) ->
    fn 'now', 'Returns the current time', -> moment()
    fn 'parse', 'Parses a time', (o) -> time.parse

    from_ymd_string: (s) ->
      moment.utc s, 'YYYYMMDD'

    from_ymd_int: (i) ->
      time.from_ymd_string i.toString()

    parse: (o) ->
      if _.isNumber o
        if o < 10e7 # maybe a date int
          time.from_ymd_int o
        else if o < 10e9 # seconds
          moment.unix(o).utc()
        else if o < 10e12 # milliseconds
          moment.utc o
        else if o < 10e15 # microseconds
          moment.utc o / 10e2
        else if o < 10e18 # nanoseconds
          moment.utx o / 10e5
        else # divide by 10 until < 10e12
          # TODO this will choose 2286 over 2001
          moment.utc o * Math.pow(10, 12 - ~~(Math.log(o) / Math.LN10))

    parse_graphite_offset: (s) ->
      s = s.toLowerCase()
      d = moment.duration 0
      if s[0] == '+' or s[0] == '-'
        sign = {'+': 1, '-': -1}[s[0]]
      else
        sign = 1
      s = s.substr 1
      while s.length > 0
        i = 1

