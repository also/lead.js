underscore = require 'underscore'

underscore.extend module.exports, underscore,
  intersperse: (array, v) ->
    result = array[...1]
    underscore.each array[1...], (e) ->
      result.push v, e
    result
