CodeMirror = require 'codemirror'
_ = require 'underscore'
React = require './react_abuse'
Context = require './context'

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
  mixins: [Context.ContextAwareMixin]
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
  renderCode: -> format_code @props.value, @props.language, @getDOMNode()
  render: -> React.DOM.pre()
  componentDidMount: -> @renderCode()
  componentDidUpdate: -> @renderCode()


TreeNodeComponent = React.createClass
  displayName: 'TreeNodeComponent'
  propTypes:
    node: React.PropTypes.shape({
      path: React.PropTypes.string.isRequired
      is_leaf: React.PropTypes.bool.isRequired
    }).isRequired
    tree_state: React.PropTypes.object.isRequired
    value: React.PropTypes.func.isRequired
    create_node: React.PropTypes.func.isRequired
    create_error_node: React.PropTypes.func.isRequired
  render: ->
    path = @props.node.path
    state = @props.tree_state[path]

    if state == 'open'
      child_nodes = _.map @props.value(path), (child) =>
        @props.create_node _.extend {}, @props, {node: child}
      child = React.DOM.ul null, _.sortBy child_nodes, (node) -> node.props.name
    else if state == 'failed'
      child = @props.create_error_node props
    else
      child = null
    if @props.node.is_leaf
      toggle = 'fa fa-fw'
    else if state == 'open' or state == 'failed'
      toggle = 'fa fa-fw fa-caret-down'
    else if state == 'opening'
      toggle = 'fa fa-fw fa-spinner fa-spin'
    else
      toggle = 'fa fa-fw fa-caret-right'
    React.DOM.li null,
      React.DOM.span({onClick: @handle_click},
        React.DOM.i {className: toggle}
        @props.children)
        React.DOM.div {className: 'child'}, child
  handle_click: ->
    path = @props.node.path
    state = @props.tree_state[path]
    if @props.node.is_leaf
      @props.load path
    else
      @props.toggle path

TreeComponent = React.createClass
  displayName: 'TreeComponent'
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
    React.DOM.ul {className: 'simple-tree'},
      @props.create_node {
        value: @value
        tree_state: @state.tree_state
        node: {path: @props.root, is_leaf: false}
        toggle: @toggle
        load: @props.load
        create_node: @props.create_node
        create_error_node: @props.create_error_node
      }, name

ToggleComponent = React.createClass
  displayName: 'ToggleComponent'
  getInitialState: ->
    open: @props.initially_open or false
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

module.exports = {ExampleComponent, SourceComponent, TreeNodeComponent, TreeComponent, ToggleComponent}
