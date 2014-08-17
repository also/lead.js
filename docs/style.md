## Promise Status

    Q = require 'q'
    input.live input.button('Show Promise Status'), ->
      promise_status Q.delay(2000)

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
    Context.add_component ctx, Builtins.ComponentAndError {promise: Q.reject 'nope'}, 'Component Goes Here'
    ignore

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

    try
      throw new Error 'nope'
    catch e
      error e
