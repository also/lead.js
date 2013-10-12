Q = require 'q'

num_points = 1000
num_series = 10

random_series = ->
  value = 0
  _.map _.range(num_points), (i) ->
    value += (Math.random() - .5) * 10
    [value, new Date() / 1000 + (i * 60)]

series = _.map _.range(num_series), (t) ->
  target: t
  datapoints: random_series()

graph Q series
