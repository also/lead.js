define (require) ->
  React = require 'react'
  _ = require 'underscore'
  Bacon = require 'bacon.model'

  createIdentityClass = (args...) ->
    cls = React.createClass args...
    prefix = cls.originalSpec.displayName ? 'identity'
    (props, args...) ->
      props ?= {}
      props.key = "#{prefix}_#{ComponentListMixin.component_id++}"
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

  ComponentListMixin =
    getInitialState: -> components: @_components or [], update_count: 0
    assign_key: (component) ->
        component.props.key ?= "component_#{ComponentListMixin.component_id++}"
    set_components: (@_components) ->
      _.each @_components, @assign_key
      @_update_state()
    _update_state: ->
      @setState components: @_components, update_count: @state.update_count + 1 if @state
    did_state_change: (next_state) ->
      return next_state.update_count != @state.update_count
  ComponentListMixin.component_id = 0

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

  ComponentList = React.createClass
    displayName: 'ComponentList'
    mixins: [ComponentListMixin]
    add_component: (c) ->
      @assign_key c
      @_components ?= []
      @_components.push c
      @_update_state()
    empty: ->
      @_components = []
      @_update_state()
    render: ->
      React.DOM.div {}, @state.components
    shouldComponentUpdate: (next_props, next_state) -> @did_state_change next_state

  SimpleObservableComponent = createIdentityClass
    displayName: 'SimpleObservableComponent'
    mixins: [ObservableMixin]
    render: ->
      React.DOM.div {}, @state.value

  component_list = ->
    components = []
    model = new Bacon.Model []
    _lead_render: SimpleObservableComponent observable: model
    add_component: (c) ->
      ComponentListMixin.assign_key c
      components.push c
      model.set components.slice()
    empty: ->
      components = []
      model.set []

  PropsHolder = React.createClass
    displayName: 'PropsHolder'
    render: -> @props.constructor @state.props
    getInitialState: -> props: @props.props
    set_child_props: (props) -> @setState {props: _.extend({}, @state.props, props)}

  _.extend {ComponentListMixin, ComponentList, PropsHolder, ComponentProxy, ComponentProxyMixin, ObservableMixin, component_list, createIdentityClass}, React

