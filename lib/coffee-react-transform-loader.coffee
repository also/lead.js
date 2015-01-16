transform = require('coffee-react-transform')

module.exports = (source) ->
  @cacheable()
  transform(source)
