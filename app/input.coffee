_ = require 'underscore'
Bacon = require 'bacon.model'
modules = require './modules'
React = require './react_abuse'

InputMixin =
  getInitialState: ->
    value: @props.default_value
  handle_change: (e) ->
    @setState value: e.target.value
    @props.bus.push e.target.value

# creates an input component bound to a bacon model
# changes to the input component will update the model and changes to the
# model will update the input component
create_component = (constructor, props) ->
  bus = new Bacon.Bus()
  c = React.ComponentProxy()

  props = _.extend {default_value: ''}, props, {bus, component_proxy: c}
  value = props.default_value
  bus.onValue (v) -> value = v
  model = Bacon.Binding
    events: bus
    set: (v) -> c.setState value: (v)
    get: => value
  component = constructor props
  component.model = model
  {component, model}

_InputComponent = React.createClass
  mixins: [React.ComponentProxyMixin, InputMixin]
  render: ->
    React.DOM.input type: @props.type, value: @state.value, onChange: @handle_change

_SelectComponent = React.createClass
  mixins: [React.ComponentProxyMixin, InputMixin]
  render: ->
    React.DOM.select {value: @state.value, onChange: @handle_change}, _.map @props.options, (o) ->
      if _.isArray o
        [k, v] = o
      else
        k = v = o
      React.DOM.option {value: k}, v

SelectComponent = (props) ->
  default_value = if props.default_value?
    props.default_value
  else
    v = props.options[0]
    if _.isArray v
      v[0]
    else
      v
  # TODO the selection context fn will call this with a default_value of undefined,
  # so the more natural _.extend {default_value}, props doesn't work
  create_component _SelectComponent, _.extend {}, props, {default_value}

input = modules.export exports, 'input', ({fn}) ->
  # inputs and selects return a Bacon.Model, which is a property with get and set methods
  # https://github.com/baconjs/bacon.model

  fn 'text_input', 'A text input field', (default_value='') ->
    {component, model} = create_component _InputComponent, {type: 'text', default_value}
    @add_component component
    @value model

  fn 'select', 'A select field', (options, default_value) ->
    {component, model} = SelectComponent {options, default_value}
    @add_component component
    @value model

  fn 'button', 'A button', (value) ->
    bus = new Bacon.Bus()
    @add_component React.DOM.button {onClick: (e) -> bus.push e}, value
    @value bus

  fn 'live', 'Updates when the property changes', (property, fn) ->
    @div ->
      unless property.onValue?
        property = Bacon.combineTemplate property
      property.onValue @keeping_context (v) ->
        @empty()
        @apply_to fn, [v]
