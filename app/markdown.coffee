Marked = require 'marked'
React = require 'react'
Components = require './components'
Context = require './context'
ContextComponents = require './contextComponents'
URI = require 'URIjs'
_ = require 'underscore'
CoffeeScriptCell = require './coffeescript_cell'
Documentation = require './documentation'

fix_marked_renderer_href = (fn, base_href) ->
  (href, args...) ->
    fn.call this, URI(href).absoluteTo(base_href).toString(), args...

UserHtmlComponent = React.createClass
  displayName: 'UserHtmlComponent'
  render: ->
    React.DOM.div className: 'user-html', dangerouslySetInnerHTML: __html: @props.html

MarkdownComponent = React.createClass
  displayName: 'MarkdownComponent'
  render: ->
    marked_opts = {}
    base_href = @props.opts?.base_href
    if base_href?
      renderer = new Marked.Renderer
      renderer.link = fix_marked_renderer_href renderer.link, base_href
      renderer.image = fix_marked_renderer_href renderer.image, base_href
      marked_opts.renderer = renderer
    UserHtmlComponent html: Marked @props.value, marked_opts

InlineExampleComponent = React.createClass
  displayName: 'InlineExampleComponent'
  mixins: [ContextComponents.ContextAwareMixin]
  render: ->
    exampleComponent = Components.SourceComponent displayValue: @props.displayValue, value: @props.value, language: 'coffeescript'

    # TODO should use new context
    nestedContext = Context.create_nested_context(@state.ctx, current_options: _.clone(@state.ctx.options()))
    fn = CoffeeScriptCell.create_fn(@props.value)
    Context.run_in_context(nestedContext, fn)

    React.DOM.div {className: 'inline-example'},
      React.DOM.div {className: 'example'},
        exampleComponent
        React.DOM.span {className: 'run-button', onClick: @onClick},
          React.DOM.i {className: 'fa fa-play-circle'}
          ' Edit this example'
      React.DOM.div {className: 'output'}, nestedContext.component()

  onClick: ->
    # TODO set code instead of running
    @state.ctx.run @props.value

LeadMarkdownComponent = React.createClass
  displayName: 'LeadMarkdownComponent'
  mixins: [ContextComponents.ContextAwareMixin]
  getInitialState: ->
    # FIXME #175 props can change
    image_urls = @props.image_urls ? {}
    renderer = new Marked.Renderer
    image_renderer = renderer.image.bind renderer
    renderer.image = (href, title, text) -> image_renderer image_urls[href] ? href, title, text
    opts = _.defaults {renderer}, Marked.defaults
    tokens = Marked.Lexer.lex @props.value, Marked.defaults
    current_tokens = []
    components = []
    codePrefix = null
    nextCodeOptions = {}

    _.each tokens, (t, i) ->
      if t.type != 'code'
        if t.type == 'paragraph'
          if t.text == '<!-- norun -->'
            nextCodeOptions.norun = true
          else if t.text == '<!-- noinline -->'
            nextCodeOptions.noinline = true
          else if t.text == '<!-- code-prefix -->'
            nextCodeOptions.codePrefix = true
          else if t.text == '<!-- skip-code-prefix -->'
            nextCodeOptions.skipCodePrefix = true
          else
            current_tokens.push t
        else
          current_tokens.push t
      else
        if current_tokens.length > 0
          current_tokens.links = tokens.links
          components.push UserHtmlComponent html: Marked.Parser.parse current_tokens, opts
          current_tokens = []
        value = t.text.trim()
        if codePrefix? and !nextCodeOptions.skipCodePrefix
          script = codePrefix + '\n' + value
        else
          script = value
        if nextCodeOptions.norun
          components.push Components.SourceComponent {displayValue: value, value: script, language: 'coffeescript'}
        else if nextCodeOptions.noinline
          components.push Components.ExampleComponent {displayValue: value, value: script, run: true}
        else if nextCodeOptions.codePrefix
          codePrefix = value
        else
          components.push InlineExampleComponent {displayValue: value, value: script}

        nextCodeOptions = {}

    if current_tokens.length > 0
      current_tokens.links = tokens.links
      components.push UserHtmlComponent html: Marked.Parser.parse current_tokens, opts
    {components}
  render: ->
    React.DOM.div className: 'lead-markdown', @state.components...
  componentDidMount: ->
    _.each @getDOMNode().querySelectorAll('a'), (a) =>
      a.addEventListener 'click', (e) =>
        uri = URI a.href
        if uri.protocol() == 'help'
          e.preventDefault()
          Documentation.navigate @state.ctx, uri.path()

_.extend exports, {MarkdownComponent, LeadMarkdownComponent}
