define (require) ->
  Marked = require 'marked'
  React = require 'react_abuse'

  fix_marked_renderer_href = (fn, base_href) ->
    (href, args...) ->
      fn URI(href).absoluteTo(base_href).toString(), args...

  MarkdownComponent = React.createClass
    render: ->
      marked_opts = {}
      base_href = @props.opts?.base_href
      if base_href?
        renderer = new Marked.Renderer
        renderer.link = fix_marked_renderer_href renderer.link, base_href
        renderer.image = fix_marked_renderer_href renderer.image, base_href
        marked_opts.renderer = renderer
      React.DOM.div className: 'user-html', dangerouslySetInnerHTML: __html: Marked @props.value, marked_opts

  {MarkdownComponent}

