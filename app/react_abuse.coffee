React = require 'react/lib/ReactWithAddons'
_ = require 'underscore'
Bacon = require 'bacon.model'

component_id = 1

createIdentityClass = (args...) ->
  cls = React.createClass args...
  prefix = cls.originalSpec.displayName ? 'identity'
  (props, args...) ->
    props ?= {}
    props.key = "#{prefix}_#{component_id++}"
    cls props, args...

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

SimpleObservableComponent = createIdentityClass
  displayName: 'SimpleObservableComponent'
  mixins: [ObservableMixin]
  render: ->
    React.DOM.div {}, @state.value

component_list = ->
  components = []
  model = new Bacon.Model []

  model: model
  component: SimpleObservableComponent observable: model
  add_component: (c) ->
    unless c.props.key?
      c = React.addons.cloneWithProps c, key: "#{c.constructor.displayName ? 'component'}_#{component_id++}"
    components.push c
    model.set components.slice()
  empty: ->
    components = []
    model.set []

PropsModelComponent = createIdentityClass
  displayName: 'PropsModelComponent'
  mixins: [ObservableMixin]
  get_observable: -> @props.child_props
  render: -> @props.constructor @state.value

_.extend exports, {PropsModelComponent, ObservableMixin, component_list, createIdentityClass}, React

