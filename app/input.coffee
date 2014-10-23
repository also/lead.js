_ = require 'underscore'
React = require 'react'
Bacon = require 'bacon.model'
modules = require './modules'
Context = require './context'
Components = require './components'

InputMixin = _.extend {}, Components.ObservableMixin,
  get_observable: -> @props.model
  handle_change: (e) ->
    @props.model.set e.target.value

# creates an input component bound to a bacon model
# changes to the input component will update the model and changes to the
# model will update the input component
create_component = (constructor, props) ->
  model = Bacon.Model if props.default_value then String(props.default_value) else ''

  props = _.extend props, {model}
  component = constructor props
  {component, model}

SelectComponent = React.createClass
  displayName: 'SelectComponent'
  mixins: [InputMixin]
  render: ->
    React.DOM.select {value: @state.value, onChange: @handle_change}, _.map @props.options, (o) ->
      if _.isArray o
        [k, v] = o
      else
        k = v = o
      React.DOM.option {value: k}, v

InputComponent = React.createClass
  displayName: 'InputComponent'
  mixins: [InputMixin]
  render: ->
    React.DOM.input type: @props.type, value: @state.value, onChange: @handle_change

input = modules.export exports, 'input', ({fn}) ->
  # inputs and selects return a Bacon.Model, which is a property with get and set methods
  # https://github.com/baconjs/bacon.model

  fn 'text_input', 'A text input field', (ctx, default_value='') ->
    {component, model} = create_component InputComponent, {type: 'text', default_value}
    Context.add_component ctx, component
    Context.value model

  fn 'select', 'A select field', (ctx, options, default_value) ->
    unless default_value
      v = options[0]
      default_value = if _.isArray v
        v[0]
      else
        v
    {component, model} = create_component SelectComponent, {options, default_value}
    Context.add_component ctx, component
    Context.value model

  fn 'button', 'A button', (ctx, value) ->
    bus = new Bacon.Bus()
    Context.add_component ctx, React.DOM.button {onClick: (e) -> bus.push e}, value
    Context.value bus

  fn 'live', 'Updates when the property changes', (ctx, property, fn) ->
    Context.nested_item ctx, (ctx) ->
      unless property.onValue?
        property = Bacon.combineTemplate property
      property.onValue (v) ->
        Context.remove_all_components ctx
        Context.apply_to ctx, fn, [v]
