underscore = require 'underscore'

underscore.extend module.exports, underscore,
  intersperse: (array, v) ->
    result = array[...1]
    underscore.each array[1...], (e) ->
      result.push v, e
    result

  startsWith: (str, starts) ->
      if starts == ''
        return true
      if str == null || starts == null
        return false
      str = String(str)
      starts = String(starts)
      str.length >= starts.length && str.slice(0, starts.length) == starts
