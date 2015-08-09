React = require 'react'
Bacon = require 'baconjs'
_ = require 'underscore'
Server = require './server'
Graphing = require './graphing'
Editor = require './editor'
Context = require './context'
CoffeeScriptCell = require './coffeescript_cell'
Components = require './components'
ContextComponents = require './contextComponents'
AppAwareMixin = require('./appAwareMixin')

remove_target = (targets, target) ->
  targets.modify (targets) ->
    _.without targets, target

TargetsEditorComponent = React.createClass
  displayName: 'TargetsEditorComponent'
  mixins: [Components.ObservableMixin]
  getObservable: (props) -> props.targets
  remove_target: (target) ->
    remove_target @props.targets, target
  render: ->
    React.DOM.ul {className: 'targets-editor'},
      _.map @state.value, (target, i) =>
        React.DOM.li null,
          React.DOM.i {className: 'fa fa-minus-circle', onClick: => @remove_target target}
          TargetEditorComponent target: @props.targets.lens '' + i

TargetEditorComponent = React.createClass
  displayName: 'TargetEditorComponent'
  make_segment_wildcard: (i) ->
    path = @props.target.get()
    segments = path.split '.'
    segments[i] = '*'
    @props.target.set segments.join '.'
  render: ->
    path = @props.target.get()
    segments = path.split '.'
    React.DOM.span {className: 'target-editor'},
      _.map segments, (segment, i) =>
        is_wildcard = segment != '*'
        if is_wildcard
          className = 'target-segment'
        else
          className = ''
        if i is 0
          result = []
        else
          result = ['.']
        result.push React.DOM.span {className, onClick: => @make_segment_wildcard i},
          React.DOM.span {className: 'target-segment-name'}, segment
          if is_wildcard
            React.DOM.span {className: 'target-segment-menu'},
              '*'
        result

exports.BuilderComponent = React.createClass
  displayName: 'BuilderComponent'
  mixins: [AppAwareMixin]

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
        Bacon.fromPromise Server.get_data _.defaults {target: targets}, server_params
      else
        Bacon.once []
    data = Bacon.Model()
    data.addSource render_results

    ctx: Context.create_standalone_context {imports: ['server'], modules: @context.app.modules}
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
    Context.remove_all_components ctx
    fn ctx
    @state.params.set _.clone ctx.current_options

  render: ->
    React.DOM.div {className: 'builder'},
      React.DOM.div {className: 'output tree'},
        Server.MetricTreeComponent
          root: @props.root
          leafClicked: (path) =>
            @state.leaf_clicks.push path
      React.DOM.div {className: 'output main'},
        Components.ToggleComponent {title: 'Targets'},
          TargetsEditorComponent targets: @state.targets
        Graphing.GraphComponent model: @state.model
        ContextComponents.ComponentContextComponent ctx: @state.ctx,
          Editor.EditorComponent {run: @run, ref: 'editor'}
          Context.ContextOutputComponent {}
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
