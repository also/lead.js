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

# Output
## Text

    text 'Hello, World'

## HTML

    html "<font color=blue>HTML</font>"

## Example

    example "example 'Yo dawg i heard you like examples…'"
