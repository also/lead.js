React = require('react/addons')
_ = require 'underscore'

NodePropType = React.PropTypes.shape({
  path: React.PropTypes.string.isRequired
  name: React.PropTypes.string.isRequired
  isLeaf: React.PropTypes.bool.isRequired
})

TreeNodeComponent = React.createClass
  contextTypes:
    nodeClass: React.PropTypes.func.isRequired
    errorNodeClass: React.PropTypes.func.isRequired
    tree_state: React.PropTypes.object.isRequired
    value: React.PropTypes.func.isRequired
    toggle: React.PropTypes.func.isRequired
    leafClicked: React.PropTypes.func.isRequired

  propTypes:
    node: NodePropType.isRequired

  render: ->
    {node, children} = @props
    {nodeClass, errorNodeClass} = @context
    {path} = node
    state = @context.tree_state[path]

    if state == 'open'
      sortedNodes = _.sortBy @context.value(path), (child) -> child.name
      child_nodes = _.map sortedNodes, (child) =>
        <nodeClass node={child}/>

      child = <ul>{child_nodes}</ul>

    else if state == 'failed'
      child = <errorNodeClass {... @props}/>
    else
      child = null

    if node.isLeaf
      toggle = 'fa fa-fw'
    else if state == 'open' or state == 'failed'
      toggle = 'fa fa-fw fa-caret-down'
    else if state == 'opening'
      toggle = 'fa fa-fw fa-spinner fa-spin'
    else
      toggle = 'fa fa-fw fa-caret-right'

    <li>
      <span onClick={@handle_click}>
        <i className={toggle}/>
        {children}
      </span>
      <div className='child'>{child}</div>
    </li>

  handle_click: ->
    path = @props.node.path
    state = @context.tree_state[path]
    if @props.node.isLeaf
      @context.leafClicked(path)
    else
      @context.toggle(path)


TreeComponent = React.createClass
  propTypes:
    root: NodePropType
    leafClicked: React.PropTypes.func.isRequired
    loadChildren: React.PropTypes.func.isRequired
    nodeClass: React.PropTypes.func.isRequired
    errorNodeClass: React.PropTypes.func.isRequired

  childContextTypes:
    nodeClass: React.PropTypes.func.isRequired
    errorNodeClass: React.PropTypes.func.isRequired
    tree_state: React.PropTypes.object.isRequired
    value: React.PropTypes.func.isRequired
    toggle: React.PropTypes.func.isRequired
    leafClicked: React.PropTypes.func.isRequired

  getDefaultProps: ->
    root: ''

  getInitialState: ->
    cache: {}
    tree_state: {}

  toggle: (path) ->
    state = @state.tree_state[path]
    if state == 'closed' or !state?
      @open path
    else
      @close path

  value: (path) ->
    @state.cache[path]?.inspect()?.value

  open: (path) ->
    tree_state = _.clone @state.tree_state
    cache = _.clone @state.cache

    state = @state.cache[path]
    if state?.isFulfilled()
      tree_state[path] = 'open'
    else
      tree_state[path] = 'opening'

      if !state or state.isRejected()
        promise = @props.loadChildren path
        cache[path] = promise
        promise.then (result) =>
          return unless @state.cache[path] == promise
          tree_state = _.clone @state.tree_state
          tree_state[path] = 'open'
          @setState {tree_state}
        , (err) =>
          return unless @state.cache[path] == promise
          tree_state = _.clone @state.tree_state
          tree_state[path] = 'failed'
          @setState {tree_state}

    @setState {tree_state, cache}

  close: (path) ->
    tree_state = _.clone @state.tree_state
    tree_state[path] = 'closed'
    cache = @state.cache
    if cache[path]?.isRejected()
      cache = _.clone cache
      delete cache[path]
    @setState {tree_state, cache}

  componentWillMount: ->
    @open @props.root

  getChildContext: ->
    tree_state: @state.tree_state
    nodeClass: @props.nodeClass
    errorNodeClass: @props.errorNodeClass
    value: @value
    toggle: @toggle
    leafClicked: @props.leafClicked

  render: ->
    <ul className="simple-tree"><@props.nodeClass node={@props.root}/></ul>


module.exports = {TreeNodeComponent, TreeComponent}