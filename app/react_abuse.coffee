React = require 'react/lib/ReactWithAddons'
_ = require 'underscore'
Bacon = require 'bacon.model'

component_id = 1

createIdentityClass = (args...) ->
  cls = React.createClass args...
  prefix = cls.originalSpec.displayName ? 'identity'
  (props, args...) ->
    props ?= {}
    props.key = "#{prefix}_#{component_id++}"
    cls props, args...

generate_component_id = -> component_id++

ObservableMixin =
  #get_observable: -> @props.observable
  getInitialState: ->
    value = null
    observable = @get_observable?() ? @props.observable
    observable: observable
    # there might already be a value, so the onValue callback can be called inside getInitialState
    unsubscribe: observable.onValue (v) =>
      @setState value: v
      value = v
    value: value
  componentWillUnmount: ->
    @state.unsubscribe()

SimpleObservableComponent = createIdentityClass
  displayName: 'SimpleObservableComponent'
  mixins: [ObservableMixin]
  render: ->
    React.DOM.div {}, @state.value

SimpleLayoutComponent = createIdentityClass
  displayName: 'SimpleLayoutComponent'
  render: ->
    React.DOM.div {}, @props.children

PropsModelComponent = createIdentityClass
  displayName: 'PropsModelComponent'
  mixins: [ObservableMixin]
  get_observable: -> @props.child_props
  render: -> @props.constructor @state.value

_.extend exports, {PropsModelComponent, ObservableMixin, SimpleLayoutComponent, createIdentityClass, generate_component_id}, React

