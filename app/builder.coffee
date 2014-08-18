React = require './react_abuse'
Bacon = require 'baconjs'
_ = require 'underscore'
Graphite = require './graphite'
Graph = require './graph'
Editor = require './editor'
Context = require './context'
CoffeeScriptCell = require './coffeescript_cell'
Components = require './components'

EditorComponent = React.createClass
  displayName: 'EditorComponent'
  propTypes:
    run: React.PropTypes.func.isRequired
  mixins: [Context.ContextAwareMixin]
  getInitialState: ->
    editor: Editor.create_editor 'context'
  run: ->
    @props.run @state.editor.getValue()
  componentDidMount: ->
    editor = @state.editor
    editor.ctx = @state.ctx
    editor.run = @run
    @getDOMNode().appendChild editor.display.wrapper
    editor.refresh()
  get_value: ->
    @state.editor.getValue()
  render: ->
    React.DOM.div {className: 'code'}

remove_target = (targets, target) ->
  targets.modify (targets) ->
    _.without targets, target

TargetsEditorComponent = React.createClass
  displayName: 'TargetsEditorComponent'
  mixins: [React.ObservableMixin]
  get_observable: -> @props.targets
  remove_target: (target) ->
    remove_target @props.targets, target
  render: ->
    React.DOM.ul {className: 'targets-editor'},
      _.map @state.value, (target) =>
        React.DOM.li null,
          React.DOM.i {className: 'fa fa-minus-circle', onClick: => @remove_target target}
          target

exports.BuilderComponent = React.createClass
  displayName: 'BuilderComponent'
  getInitialState: ->
    leaf_clicks = new Bacon.Bus()
    targets = Bacon.Model([])
    params = Bacon.Model({})
    server_params = Bacon.Model({})
    targets.apply leaf_clicks.map (path) ->
      (targets) ->
        result = targets.slice()
        result.push path
        _.uniq result
        result
    render_results = targets.combine(server_params, (targets, server_params) -> {targets, server_params}).flatMapLatest ({targets, server_params}) ->
      if targets.length > 0
        Bacon.fromPromise Graphite.get_data _.defaults {target: targets}, server_params
      else
        Bacon.once []
    data = Bacon.Model()
    data.addSource render_results

    ctx: Context.create_standalone_context {imports: ['graphite'], ref: 'ctx'}
    model: Bacon.Model.combine {data, params}
    leaf_clicks: leaf_clicks
    params: params
    server_params: server_params
    targets: targets
  run: (value) ->
    value ?= @refs.editor.get_value()
    fn = CoffeeScriptCell.create_fn value
    ctx = @state.ctx
    #ctx.current_options = {}
    Context.run_in_context ctx, fn
    @state.params.set _.clone ctx.current_options

  render: ->
    React.DOM.div {className: 'builder'},
      React.DOM.div {className: 'output tree'},
        Graphite.MetricTreeComponent
          root: @props.root
          leaf_clicked: (path) =>
            @state.leaf_clicks.push path
      React.DOM.div {className: 'output main'},
        Graph.GraphComponent model: @state.model
        Components.ToggleComponent {title: 'Targets'},
          TargetsEditorComponent targets: @state.targets
        Context.ComponentContextComponent ctx: @state.ctx,
          EditorComponent {run: @run, ref: 'editor'}
        React.DOM.span {className: 'run-button', onClick: => @run()},
          React.DOM.i {className: 'fa fa-play-circle'}
          ' Run'
        ' '
        React.DOM.span {
          className: 'run-button',
          onClick: =>
            @run()
            @state.server_params.set @state.params.get()
          },
          React.DOM.i {className: 'fa fa-refresh'}
          ' Update graph data'
