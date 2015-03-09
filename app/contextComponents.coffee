React = require 'react'
_ = require 'underscore'

contexts_by_root_node_id = {}

find_ancestor_contexts = (component_instance) ->
  result = []
  _.each React.__internals.InstanceHandles.traverseAncestors component_instance._rootNodeID, (id) ->
    context = contexts_by_root_node_id[id]
    if context
      result.unshift context
  result

ContextRegisteringMixin =
  componentWillMount: ->
    contexts_by_root_node_id[@_rootNodeID] = @props.ctx
  componentWillUnmount: ->
    delete contexts_by_root_node_id[@_rootNodeID]

ContextAwareMixin =
  getInitialState: ->
    # TODO update later in lifecycle
    ctx: find_ancestor_contexts(@)[0]

  ctx: -> @state.ctx

ComponentContextComponent = React.createClass
  displayName: 'ComponentContextComponent'
  mixins: [ContextRegisteringMixin]
  render: -> React.DOM.div null, @props.children

_.extend exports, {
  ComponentContextComponent,
  ContextAwareMixin,
  ContextRegisteringMixin
}
