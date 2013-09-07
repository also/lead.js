define (require) ->
  $ = require 'jquery'
  _ = require 'underscore'
  bacon = require 'bacon'
  modules = require 'modules'

  input = modules.create 'input', ({fn}) ->
    fn 'text_input', 'A text input field', ->
      $input = $ '<input type="text"/>'
      @output $input
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
      @output $select
      @value $select.asEventStream('change').map((e) -> $(event.target).val()).toProperty($select.val())

    fn 'button', 'A button', (value) ->
      $button = $ '<button>'
      @output $button
      $button.text value
      @value $button.asEventStream('click')

    fn 'live', 'Updates when the property changes', (property, fn) ->
      $output = $ "<div class='live'/>"
      @nested_item $output, ->
        context = @
        unless property.onValue?
          property = Bacon.combineTemplate property
        property.onValue (v) ->
          $output.empty()
          context.in_context context, ->
            fn v
