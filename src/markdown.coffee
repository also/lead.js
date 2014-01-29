define (require) ->
  Marked = require 'marked'
  React = require 'react_abuse'
  Components = require 'components'
  URI = require 'URIjs'

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

  LeadMarkdownComponent = React.createClass
    componentWillMount: ->
      codes = []
      renderer = new Marked.Renderer
      renderer.code = (code, language) ->
        result = "<div data-lead-code-index='#{codes.length}'></div>"
        codes.push {code, language}
        result
      @setState html: Marked(@props.value, {renderer}), codes: codes
    render: ->
      React.DOM.div className: 'user-html', dangerouslySetInnerHTML: __html: @state.html
    componentDidMount: (node) ->
      _.each @state.codes, (code, i) =>
        example_component = Components.ExampleComponent ctx: @props.ctx, value: code.code.trim(), run: true
        code_node = node.querySelector "div[data-lead-code-index='#{i}']"
        React.renderComponent example_component, code_node
      _.each node.querySelectorAll('a'), (a) =>
        a.addEventListener 'click', (e) =>
          uri = URI a.href
          if uri.protocol() == 'help'
            e.preventDefault()
            @props.ctx.run "help #{JSON.stringify uri.path()}"

  {MarkdownComponent, LeadMarkdownComponent}

