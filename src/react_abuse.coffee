define (require) ->
  React = require 'react'
  _ = require 'underscore'
  Bacon = require 'bacon.model'

  component_id = 1
  assign_key = (component) ->
    component.props.key ?= "component_#{component_id++}"

  createIdentityClass = (args...) ->
    cls = React.createClass args...
    prefix = cls.originalSpec.displayName ? 'identity'
    (props, args...) ->
      props ?= {}
      props.key = "#{prefix}_#{component_id++}"
      cls props, args...

  ComponentProxy = ->
    component = null
    state = null
    bind_to_component: (c) ->
      component = c
      if state != null
        component.setState state
    setState: (s) ->
      if component?
        component.setState s
      else
        state = s

  ComponentProxyMixin =
    componentWillMount: ->
      @props.component_proxy?.bind_to_component @

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

  component_list = ->
    components = []
    model = new Bacon.Model []

    model: model
    _lead_render: SimpleObservableComponent observable: model
    add_component: (c) ->
      assign_key c
      components.push c
      model.set components.slice()
    empty: ->
      components = []
      model.set []

  PropsModelComponent = createIdentityClass
    displayName: 'PropsModelComponent'
    mixins: [ObservableMixin]
    get_observable: -> @props.child_props
    render: -> @props.constructor @state.value

  _.extend {PropsModelComponent, ComponentProxy, ComponentProxyMixin, ObservableMixin, component_list, createIdentityClass}, React

