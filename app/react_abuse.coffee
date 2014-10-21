React = require 'react/lib/ReactWithAddons'
_ = require 'underscore'
Bacon = require 'bacon.model'

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

SimpleObservableComponent = React.createClass
  displayName: 'SimpleObservableComponent'
  mixins: [ObservableMixin]
  render: ->
    React.DOM.div {}, @state.value

SimpleLayoutComponent = React.createClass
  displayName: 'SimpleLayoutComponent'
  mixins: [React.addons.PureRenderMixin]
  render: ->
    React.DOM.div {}, @props.children

PropsModelComponent = React.createClass
  displayName: 'PropsModelComponent'
  mixins: [ObservableMixin]
  get_observable: -> @props.child_props
  render: -> @props.constructor @state.value

_.extend exports, {PropsModelComponent, ObservableMixin, SimpleLayoutComponent}, React
