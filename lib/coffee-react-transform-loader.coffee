transform = require('coffee-react-transform')

module.exports = (source) ->
  @cacheable()
  try
    transform(source)
  catch e
    loc = e.location ? {}
    if e.message? and loc.first_line? and loc.first_column?
      throw new SyntaxError("#{e.message} (at #{loc.first_line}:#{loc.first_column})")
    else
      throw e
