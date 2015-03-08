React = require('react/addons')
_ = require 'underscore'

NodePropType = React.PropTypes.shape({
  path: React.PropTypes.string.isRequired
  is_leaf: React.PropTypes.bool.isRequired
})

TreeNodeComponent = React.createClass
  propTypes:
    node: NodePropType.isRequired
    tree_state: React.PropTypes.object.isRequired
    value: React.PropTypes.func.isRequired
    create_node: React.PropTypes.func.isRequired
    create_error_node: React.PropTypes.func.isRequired

  render: ->
    {node, children} = @props
    {path} = node
    state = @props.tree_state[path]

    if state == 'open'
      child_nodes = _.map @props.value(path), (child) =>
        @props.create_node _.extend {}, @props, {node: child}

      child = <ul>{_.sortBy child_nodes, (node) -> node.props.name}</ul>

    else if state == 'failed'
      child = @props.create_error_node(@props)
    else
      child = null

    if node.is_leaf
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
    state = @props.tree_state[path]
    if @props.node.is_leaf
      @props.load(path)
    else
      @props.toggle(path)


TreeComponent = React.createClass
  propTypes:
    root: React.PropTypes.string.isRequired
    load: React.PropTypes.func.isRequired
    load_children: React.PropTypes.func.isRequired
    create_node: React.PropTypes.func.isRequired
    create_error_node: React.PropTypes.func.isRequired

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
        promise = @props.load_children path
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

  render: ->
    child = @props.create_node {
      value: @value
      tree_state: @state.tree_state
      node: {path: @props.root, is_leaf: false}
      toggle: @toggle
      load: @props.load
      create_node: @props.create_node
      create_error_node: @props.create_error_node
    }, name

    <ul className="simple-tree">{child}</ul>


module.exports = {TreeNodeComponent, TreeComponent}