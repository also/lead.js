CodeMirror = require 'codemirror'
require 'codemirror/addon/runmode/runmode'
URI = require 'URIjs'
_ = require 'underscore'
React = require 'react'
Markdown = require './markdown'
modules = require './modules'
Documentation = require './documentation'
Components = require './components'
Context = require './context'
ContextComponents = require './contextComponents'
App = require './app'
{ObjectBrowserComponent} = require './objectBrowser'

ExampleComponent = Components.ExampleComponent

help_component = (ctx, o) ->
  key = Documentation.get_key ctx, o
  if key?
    doc = Documentation.get_documentation key
    return Documentation.DocumentationItemComponent {ctx, doc}
  else
    # TODO shouldn't be pre
    if _.isString o
      return React.DOM.pre null, "Documentation for #{o} not found."
    else
      return React.DOM.pre null, "Documentation not found."


ObjectComponent = React.createClass
  displayName: 'ObjectComponent'
  render: ->
    try
      s = JSON.stringify(@props.object, null, '  ')
    catch
      s = null
    try
      s ||= new String @props.object
    catch
      s = "\"(object can't be converted to a string)\""
    Components.SourceComponent value: s, language: 'json'


HtmlComponent = React.createClass
  displayName: 'HtmlComponent'
  render: -> React.DOM.div className: 'user-html', dangerouslySetInnerHTML: __html: @props.value


ErrorComponent = React.createClass
  displayName: 'ErrorComponent'
  mixins: [ContextComponents.ContextAwareMixin]
  render: ->
    errorRenderers = Context.collect_extension_points(@state.ctx, 'renderError')
    message = null
    _.find errorRenderers, (renderer) =>
      message = renderer(@props.message)

    unless message
      message = @props.message
      if not message?
        message = React.DOM.pre {}, 'Unknown error'
        # TODO include stack trace?
      else if message instanceof Error
        message = React.DOM.pre {}, message.toString()
      else if not _.isString message
        message = ObjectBrowserComponent object: message
        # TODO handle exceptions better
    React.DOM.div {className: 'error'}, message

PromiseResolvedComponent = React.createClass
  displayName: 'PromiseResolvedComponent'
  getInitialState: ->
    # FIXME #175 props can change
    @props.promise.then (v) =>
      @setState value: v, resolved: true

    value: null
    resolved: false
  render: ->
    if @state.resolved
      React.DOM.div null, @props.constructor @state.value
    else
      null

PromiseStatusComponent = React.createClass
  displayName: 'PromiseStatusComponent'
  render: ->
    if @state?.duration?
      ms = @state.duration
      duration = if ms >= 1000
        s = (ms / 1000).toFixed 1
        "#{s} s"
      else
        "#{ms} ms"
      if @props.promise.isFulfilled()
        text = "Loaded in #{duration}"
        icon = ''
      else
        text = "Failed after #{duration}"
        icon = 'fa-exclamation-triangle'
    else
      text = "Loading"
      icon = 'fa-spinner fa-spin'
    React.DOM.div {className: 'promise-status'},
      React.DOM.i {className: "fa #{icon} fa-fw"}
      " #{text}"
  getInitialState: ->
    # FIXME #175 props can change
    if @props.promise.isPending()
      null
    else
      return duration: 0
  finished: ->
    @setState duration: new Date - @props.start_time
  componentWillMount: ->
    # TODO this should probably happen earlier, in case the promise finishes before componentWillMount
    @props.promise.finally @finished

ComponentAndError = React.createClass
  displayName: 'ComponentAndError'
  componentWillMount: ->
    @props.promise.fail (e) =>
      @setState error: e
  getInitialState: -> error: null
  render: ->
    if @state.error?
      error = ErrorComponent {message: @state.error}
    React.DOM.div null, @props.children, error

ObservableComponent = React.createClass
  displayName: 'ObservableComponent'
  mixins: [Components.ObservableMixin]
  render: ->
    if @state.value?
      valueComponent = ObjectBrowserComponent object: @state.value
    else
      valueComponent = '(no value)'
    Components.ToggleComponent {title: 'Live Value'},
      valueComponent

PromiseComponent = React.createClass
  displayName: 'PromiseComponent'
  getInitialState: ->
    @props.promise.finally =>
      @setState snapshot: @props.promise.inspect()
    snapshot: @props.promise.inspect()
    startTime: new Date
  render: ->
    if @state.snapshot.state == 'pending'
      value = Components.ToggleComponent {title: 'Pending Promise'},
        '(no value)'
    else if @state.snapshot.state == 'fulfilled'
      value = Components.ToggleComponent {title: 'Fulfilled Promise'},
        ObjectBrowserComponent object: @state.snapshot.value
    else
      value = Components.ToggleComponent {title: 'Rejected Promise'},
        ObjectBrowserComponent object: @state.snapshot.reason
    React.DOM.div {}, value, PromiseStatusComponent promise: @props.promise, start_time: @state.startTime

GridComponent = React.createClass
  displayName: 'GridComponent'
  propTypes:
    cols: React.PropTypes.number.isRequired
  render: ->
    rows = []
    row = null
    cols = @props.cols
    _.each @props.children, (component, i) ->
      if i % cols == 0
        row = []
        rows.push row
      row.push React.DOM.div {style: {flex: 1}, key: i}, component
    React.DOM.div null, _.map rows, (row, i) -> React.DOM.div {key: i, style: {display: 'flex'}}, row

FlowComponent = React.createClass
  displayName: 'FlowComponent'
  render: ->
    React.DOM.div {style: {display: 'flex', flexWrap: 'wrap'}, className: 'flex-layout'}, @props.children

_.extend exports, {help_component, ExampleComponent, PromiseStatusComponent, ComponentAndError, PromiseResolvedComponent, ErrorComponent, ObjectComponent, ObjectBrowserComponent, ObservableComponent, PromiseComponent, FlowComponent}

modules.export exports, 'builtins', ({doc, fn, cmd, component_fn, component_cmd}) ->
  component_cmd 'help', 'Shows this help', (ctx, o) ->
    if arguments.length > 1
      help_component ctx, o
    else
      help_component ctx

  doc 'object',
    'Displays an object as JSON'
    """
    `object` converts an object to a string using `JSON.stringify` if possible and `new String` otherwise.
    The result is displayed using syntax highlighting.

    For example:

    ```
    object a: 1, b: 2, c: 3
    ```
    """

  component_fn 'object', (ctx, o) ->
    ObjectComponent object: o

  doc 'dir',
    'Displays a JavaScript representation of an object'
    """
    `dir` displays a JavaScript object's properties.

    For example:

    ```
    dir 1
    ```

    ```
    dir [1, 2, 3]
    ```

    ```
    class Class
    c = new Class
    AnonymousClass = ->
    ac = new AnonymousClass
    x: {y: z: 1}, n: 2, d: new Date, s: "xxx", c: c, ac: ac, un: undefined, t: true
    ```
    """

  component_fn 'dir', (ctx, object) ->
    ObjectBrowserComponent {object}


  component_fn 'md', 'Displays rendered Markdown', (ctx, string, opts) ->
    Markdown.MarkdownComponent value: string, opts: opts

  component_fn 'text', 'Displays text', (ctx, string) ->
    React.DOM.p {}, string

  component_fn 'pre', 'Displays preformatted text', (ctx, string) ->
    React.DOM.pre null, string

  component_fn 'html', 'Displays rendered HTML', (ctx, string) ->
    HtmlComponent value: string

  component_fn 'example', 'Displays a code example', (ctx, value, opts) ->
    ExampleComponent value: value, run: opts?.run ? true

  component_fn 'source', 'Displays source code with syntax highlighting', (ctx, language, value) ->
    Components.SourceComponent {language, value}

  fn 'options', 'Gets or sets options', (ctx, options) ->
    if options?
      _.extend ctx.current_options, options
    Context.value ctx.current_options

  component_cmd 'permalink', 'Create a link to the code in the input cell above', (ctx, code) ->
    code ?= ctx.previously_run()
    uri = App.raw_cell_url ctx, code
    React.DOM.a {href: uri}, uri

  component_fn 'promise_status', 'Displays the status of a promise', (ctx, promise, start_time=new Date) ->
    PromiseStatusComponent {promise, start_time}

  fn 'grid', 'Generates a grid with a number of columns', (ctx, cols, fn) ->
    nested_context = Context.create_nested_context ctx, layout: GridComponent, layout_props: {cols}
    Context.add_component ctx, nested_context.component
    Context.callUserFunctionInCtx(nested_context, fn)

  fn 'flow', 'Flows components next to each other', (ctx, fn) ->
    nested_context = Context.create_nested_context ctx, layout: FlowComponent
    Context.add_component ctx, nested_context.component
    Context.callUserFunctionInCtx(nested_context, fn)
