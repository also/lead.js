define (require) ->
  CodeMirror = require 'cm/codemirror'
  React = require 'react_abuse'

  format_code = (code, language, target) ->
    target = target.get(0) if target.get?
    if CodeMirror.runMode?
      if language == 'json'
        opts = name: 'javascript', json: true
      else
        opts = name: language
      CodeMirror.runMode code, opts, target
    else
      target.textContent = code

  ExampleComponent = React.createClass
    getDefaultProps: -> language: 'coffeescript'
    render: -> React.DOM.div {className: 'example', onClick: @on_click}, @transferPropsTo SourceComponent()
    on_click: ->
      if @props.run
        @props.ctx.run @props.value
      else
        @props.ctx.set_code @props.value

  SourceComponent = React.createClass
    render: -> React.DOM.pre()
    componentDidMount: -> format_code @props.value, @props.language, @getDOMNode()

  {ExampleComponent, SourceComponent}

