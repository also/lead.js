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
    React = require 'react'
    React.createElement Builtins.ComponentAndError, {promise: Q.reject 'nope'}, 'Component Goes Here'

## Grid

    grid 5, ->
      _.each [1..13], (i) ->
        html "<div style='background: #eee; margin: .3em; text-align: center; padding: .5em'>#{i}</div>"

## ObjectBrowserComponent

    array = [1..5]
    Class = ->
    object = string: 'string', number: 1, boolean: true, array: array, date: new Date, null: null, undefined: undefined, class: new Class
    object.object = object
    dir object
    dir array

# Output
## Text

    text 'Hello, World'

## HTML

    html "<font color=blue>HTML</font>"

## Example

    example "example 'Yo dawg i heard you like examples…'"

## Source

    source 'coffeescript', """
    React = require 'react'
    React.createElement require('builtins').ErrorComponent, {message: new Error 'nope'}
    """

## Error

    React = require 'react'
    React.createElement require('builtins').ErrorComponent, {message: new Error 'nope'}
