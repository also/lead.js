underscore = require 'underscore'

underscore.extend exports, underscore,
  logError: (message..., error) ->
    if error?.stack?.indexOf(error.message) == 0
      e = error.stack
    else
      e = error
    console.error(message..., e)

  errorInfo: (error) ->
    if !error? or underscore.isString(error)
      message = 'Error: ' + error
    else
      try
        message = '' + error
      catch
        message = 'Unknown Error'
    if error instanceof Error and error.stack
      if error.stack.indexOf(message + '\n') == 0
        stack = error.stack[message.length + 1...]
      else
        stack = error.stack
      trace = stack.split('\n')
    else
      trace = null
    {error, message, trace}

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
