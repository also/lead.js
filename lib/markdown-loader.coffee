Marked = require 'marked'
_ = require 'underscore'

module.exports = (content) ->
  images = []
  renderer = new Marked.Renderer
  renderer.image = (i) ->
    req = JSON.stringify "file?name=images/[name]-[hash].[ext]!./#{i}"
    images.push "#{JSON.stringify i}: require(#{req})"
  Marked content, {renderer}
  @cacheable true
  "module.exports = {\n  content: #{JSON.stringify content},\n  images: {\n    #{images.join ',\n    '}}};"
