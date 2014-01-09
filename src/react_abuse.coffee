define (require) ->
  React = require 'react'
  _ = require 'underscore'

  ComponentListMixin =
    getInitialState: -> components: @_components or [], update_count: 0
    assign_key: (component) ->
        component.props.key ?= "component_#{ComponentListMixin.component_id++}"
    set_components: (@_components) ->
      _.each @_components, @assign_key
      @_update_state()
    _update_state: ->
      @setState components: @_components, update_count: @state.update_count++ if @state
    did_state_change: (next_state) ->
      return next_state.update_count != @state.update_count
  ComponentListMixin.component_id = 0

  ComponentList = React.createClass
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
    render: -> @props.constructor @state.props
    getInitialState: -> props: @props.props
    set_child_props: (props) -> @setState {props: _.extend({}, @state.props, props)}

  _.extend {ComponentListMixin, ComponentList, PropsHolder}, React

