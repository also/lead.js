## Promise Status

    Q = require 'q'
    input.live input.button('Show Promise Status'), ->
      promise_status Q.delay(2000)

## Observable

    input.text_input()

## Button

    input.button 'This is a button'
    ignore

## Text Field

    input.text_input()
    ignore

## kbd

    html 'Press <kbd>Ctrl</kbd><kbd>Enter</kbd>'

## ComponentAndError

    Builtins = require 'builtins'
    Q = require 'q'
    Context = require 'context'
    Builtins.ComponentAndError {promise: Q.reject 'nope'}, 'Component Goes Here'

## Grid

    grid 5, ->
      _.each [1..13], (i) ->
        html "<div style='background: #eee; margin: .3em; text-align: center; padding: .5em'>#{i}</div>"

## ObjectBrowserComponent

    object = string: 'string', number: 1, boolean: true, array: [1..5]
    object.object = object
    dir object

# Output
## Text

    text 'Hello, World'

## HTML

    html "<font color=blue>HTML</font>"

## Object

    object a: 1, b: 2, c: 3

## Example

    example "example 'Yo dawg i heard you like examples…'"

## Source

    source 'coffeescript', """
    Q = require 'q'
    input.live input.button('Show Promise Status'), ->
      promise_status Q.delay(2000)
    """

## Error

    require('builtins').ErrorComponent {message: new Error 'nope'}
