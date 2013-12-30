define (require) ->
  $ = require 'jquery'
  _ = require 'underscore'
  bacon = require 'baconjs'
  modules = require 'modules'

  input = modules.create 'input', ({fn}) ->
    fn 'text_input', 'A text input field', ->
      $input = $ '<input type="text"/>'
      @div $input
      property = $input.asEventStream('keyup').map((e) -> $(event.target).val()).toProperty("")
      property.set_value = (val) -> $input.val val
      @value property

    fn 'select', 'A select field', (options) ->
      $select = $ '<select/>'
      $select.append _.map options, (o) ->
        if _.isArray o
          [k, v] = o
        else
          k = o
        $option = $ '<option>'
        $option.text v ? k
        $option.attr 'value', k
        $option
      @div $select
      @value $select.asEventStream('change').map((e) -> $(event.target).val()).toProperty($select.val())

    fn 'button', 'A button', (value) ->
      $button = $ '<button>'
      @div $button
      $button.text value
      @value $button.asEventStream('click')

    fn 'live', 'Updates when the property changes', (property, fn) ->
      @div ->
        unless property.onValue?
          property = Bacon.combineTemplate property
        property.onValue @keeping_context (v) ->
          @empty()
          @apply_to fn, [v]
