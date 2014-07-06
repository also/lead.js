define (require) ->
  React = require 'react'
  _ = require 'underscore'

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
      observable = @get_observable?() ? @props.observable
      observable: observable
      unsubscribe: observable.onValue (value) => @setState {value}
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

  PropsHolder = React.createClass
    displayName: 'PropsHolder'
    render: -> @props.constructor @state.props
    getInitialState: -> props: @props.props
    set_child_props: (props) -> @setState {props: _.extend({}, @state.props, props)}

  createIdentityClass = (args...) ->
    cls = React.createClass args...
    prefix = cls.originalSpec.displayName ? 'identity'
    (props, args...) ->
      props ?= {}
      props.key = "#{prefix}_#{ComponentListMixin.component_id++}"
      cls props, args...


  _.extend {ComponentListMixin, ComponentList, PropsHolder, ComponentProxy, ComponentProxyMixin, ObservableMixin, createIdentityClass}, React

