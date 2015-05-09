CodeMirror = require 'codemirror'
_ = require 'underscore'
React = require 'react/addons'
Bacon = require 'bacon.model'
ContextComponents = require './contextComponents'

format_code = (code, language, target) ->
  target = target.get(0) if target.get?
  if CodeMirror.runMode?
    if language == 'json'
      opts = name: 'javascript', json: true
    else
      opts = name: language
    CodeMirror.runMode code, opts, target
  else
    target.textContent = code

ExampleComponent = React.createClass
  displayName: 'ExampleComponent'
  mixins: [ContextComponents.ContextAwareMixin]
  getDefaultProps: -> language: 'coffeescript'
  render: ->
    React.DOM.div {className: 'example'},
      @transferPropsTo SourceComponent()
      React.DOM.span {className: 'run-button', onClick: @on_click},
        React.DOM.i {className: 'fa fa-play-circle'}
        ' Run this example'
  on_click: ->
    if @props.run
      @state.ctx.run @props.value
    else
      @state.ctx.set_code @props.value

SourceComponent = React.createClass
  displayName: 'SourceComponent'
  renderCode: -> format_code @props.displayValue ? @props.value, @props.language, @getDOMNode()
  render: -> React.DOM.pre()
  componentDidMount: -> @renderCode()
  componentDidUpdate: -> @renderCode()


ToggleComponent = React.createClass
  displayName: 'ToggleComponent'
  getInitialState: ->
    open: @props.initiallyOpen or false
  toggle: (e) ->
    e.stopPropagation()
    @setState open: !@state.open
  render: ->
    if @state.open
      toggle_class = 'fa-caret-down'
    else
      toggle_class = 'fa-caret-right'
    React.DOM.div {className: 'toggle-component'},
      React.DOM.div {className: 'toggle', onClick: @toggle},
        React.DOM.i {className: "fa fa-fw #{toggle_class}"}
        React.DOM.div {className: 'toggle-title'},
          @props.title
      if @state.open
        React.DOM.div {},
          React.DOM.i {className: "fa fa-fw"}
            React.DOM.div {className: 'toggle-body'},
              @props.children

ObservableMixin =
  #getObservable: (props, context) -> props.observable
  _getObservable: (props, context) ->
    @getObservable?(props, context) ? props.observable
  componentWillMount: ->
    @init(@_getObservable(@props, @context))
  componentWillReceiveProps: (nextProps, nextContext) ->
    observable = @_getObservable?(nextProps, nextContext)
    if @state.observable != observable
      @init(observable)
  init: (observable) ->
    @state?.unsubscribe?()
    value = null
    error = null
    @setState
      observable: observable
      # there might already be a value, so the onValue callback can be called before init returns
      unsubscribe: observable.subscribe (event) =>
        if event.isError()
          error = event.error
          try
            @setState {error}
          catch e
            # TODO what's the right way to handle this?
            console.error(e)
        else if event.hasValue()
          value = event.value()
          try
            @setState {value, error: null}
          catch e
            # TODO what's the right way to handle this?
            console.error(e)
      value: value
  componentWillUnmount: ->
    @state.unsubscribe()

SimpleObservableComponent = React.createClass
  displayName: 'SimpleObservableComponent'
  mixins: [ObservableMixin]
  render: ->
    React.DOM.div {}, @state.value

SimpleLayoutComponent = React.createClass
  displayName: 'SimpleLayoutComponent'
  mixins: [React.addons.PureRenderMixin]
  render: ->
    React.DOM.div {}, @props.children

PropsModelComponent = React.createClass
  displayName: 'PropsModelComponent'
  mixins: [ObservableMixin]
  getObservable: -> @props.child_props
  render: -> @props.constructor @state.value

module.exports = {
  ExampleComponent, SourceComponent, ToggleComponent,
  PropsModelComponent, ObservableMixin, SimpleLayoutComponent
}
