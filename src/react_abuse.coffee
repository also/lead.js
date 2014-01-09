define (require) ->
  React = require 'react'
  _ = require 'underscore'

  ComponentListMixin =
    getInitialState: -> components: @_components or []
    assign_key: (component) ->
        component.props.key ?= "component_#{ComponentListMixin.component_id++}"
    set_components: (@_components) ->
      _.each @_components, @assign_key
      @_update_state()
    _update_state: ->
      @setState components: @_components if @state
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

  _.extend {ComponentListMixin, ComponentList}, React

