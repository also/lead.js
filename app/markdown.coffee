Marked = require 'marked'
React = require './react_abuse'
Components = require './components'
Context = require './context'
URI = require 'URIjs'
_ = require 'underscore'
CoffeeScript = require 'coffee-script'

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
  mixins: [Context.ContextAwareMixin]
  render: ->
    example_component = Components.ExampleComponent value: @props.value, run: true

    nested_context = @state.ctx.create_nested_context()
    value = @props.value
    Context.apply_to capture_context, -> Context.run_in_context @, -> @scoped_eval CoffeeScript.compile value, {bare: true}
    React.DOM.div {className: 'inline-example'}, example_component, nested_context.component

LeadMarkdownComponent = React.createClass
  displayName: 'LeadMarkdownComponent'
  mixins: [Context.ContextAwareMixin]
  getInitialState: ->
    tokens = Marked.Lexer.lex @props.value, Marked.defaults
    current_tokens = []
    components = []
    _.each tokens, (t, i) ->
      if t.type != 'code'
        if t.type == 'paragraph'
          if t.text == '<!-- norun -->'
            tokens[i + 1]?.norun = true
          else if t.text == '<!-- noinline -->'
            tokens[i + 1]?.noinline = true
          else
            current_tokens.push t
        else
          current_tokens.push t
      else
        if current_tokens.length > 0
          current_tokens.links = tokens.links
          components.push UserHtmlComponent html: Marked.Parser.parse current_tokens, Marked.defaults
          current_tokens = []
        value = t.text.trim()
        if t.norun or t.noinline
          components.push Components.ExampleComponent {value, run: t.noinline}
        else
          components.push InlineExampleComponent {value}
    if current_tokens.length > 0
      current_tokens.links = tokens.links
      components.push UserHtmlComponent html: Marked.Parser.parse current_tokens, Marked.defaults
    {components}
  render: ->
    React.DOM.div className: 'lead-markdown', @state.components
  componentDidMount: ->
    _.each @getDOMNode().querySelectorAll('a'), (a) =>
      a.addEventListener 'click', (e) =>
        uri = URI a.href
        if uri.protocol() == 'help'
          e.preventDefault()
          @state.ctx.run "help #{JSON.stringify uri.path()}"

module.exports = {MarkdownComponent, LeadMarkdownComponent}

