React = require 'react'
_ = require './core'

Toggleable =
  getInitialState: ->
    open: @props.initiallyOpen or false
  toggle: (e) ->
    e.stopPropagation()
    @setState open: !@state.open
  toggleClass: ->
    if @state.open
      'fa-caret-down'
    else
      'fa-caret-right'

ObjectBrowserComponent = React.createClass
  displayName: 'ObjectBrowserComponent'
  getDefaultProps: ->
    showProto: true
  render: ->
    React.DOM.div {className: 'object-browser'},
      if isSimple @props.object
        componentForObject @props.object
      else if _.isArray @props.object
        ObjectBrowserTopLevelArrayComponent @props
      else
        ObjectBrowserTopLevelObjectComponent @props

ObjectBrowserTopLevelObjectComponent = React.createClass
  displayName: 'ObjectBrowserTopLevelObjectComponent'
  mixins: [Toggleable]
  render: ->
    React.DOM.div {},
      React.DOM.div {onClick: @toggle},
        React.DOM.i {className: "fa fa-fw #{@toggleClass()}"}
          OneLineObjectComponent object: @props.object
      if @state.open
        React.DOM.div {},
          # spacer lol
          React.DOM.i {className: "fa fa-fw"}
          ObjectBrowserEntriesComponent object: @props.object, showProto: @props.showProto


ObjectBrowserTopLevelArrayComponent = React.createClass
  displayName: 'ObjectBrowserTopLevelArrayComponent'
  mixins: [Toggleable]
  render: ->
    React.DOM.div {},
      React.DOM.div {onClick: @toggle},
        React.DOM.i {className: "fa fa-fw #{@toggleClass()}"}
        OneLineArrayComponent object: @props.object
      if @state.open
        React.DOM.div {},
          # spacer lol
          React.DOM.i {className: "fa fa-fw"}
          ObjectBrowserEntriesComponent object: @props.object, showProto: @props.showProto

OneLineArrayComponent = React.createClass
  displayName: 'OneLineArrayComponent'
  render: ->
    children = _.map @props.object[...20], (v) ->
      ObjectBrowserSummaryComponent object: v
    React.DOM.span {},
      React.DOM.span {className: 'cm-punctuation'}, '['
      _.intersperse children, React.DOM.span {className: 'cm-punctuation'}, ', '
      React.DOM.span {className: 'cm-punctuation'}, ']'

OneLineObjectComponent = React.createClass
  displayName: 'OneLineObjectComponent'
  render: ->
    React.DOM.span {},
      React.DOM.span {className: 'cm-variable'}, 'Object'
      React.DOM.span {className: 'cm-punctuation'}, ' {'
      # TODO only ownProperties
      _.intersperse _.map(Object.keys(@props.object)[..5], (key) =>
          try
            child = ObjectBrowserSummaryComponent object: @props.object[key]
          catch e
            child = '(error in getter)'
          React.DOM.span {},
            React.DOM.span {className: 'cm-variable'}, key
            React.DOM.span {className: 'cm-punctuation'}, ': '
            child
        ),
        React.DOM.span {className: 'cm-punctuation'}, ', '
      React.DOM.span {className: 'cm-punctuation'}, '}'


ObjectBrowserEntriesComponent = React.createClass
  displayName: 'ObjectBrowserEntriesComponent'
  getInitialState: ->
    visibleEntries: 50
  expand: (e) ->
    e.stopPropagation()
    @setState visibleEntries: @state.visibleEntries * 2
  render: ->
    proto = Object.getPrototypeOf @props.object
    props = _.without(Object.getOwnPropertyNames(@props.object), '__proto__')
    React.DOM.div {style: display: 'inline-block'},
      _.map props[...@state.visibleEntries], (key) =>
        try
          value = @props.object[key]
        catch e
          value = null
        enumerable = Object.getOwnPropertyDescriptor(@props.object, key).enumerable
        ObjectBrowserEntryComponent {key, value, enumerable}
      if props.length > @state.visibleEntries
        React.DOM.div {onClick: @expand, className: 'run-button'}, 'Show more'
      if proto? and @props.showProto
        ObjectBrowserEntryComponent {key: '__proto__', value: proto, own: false}

isSimple = (o) ->
  return (!o?) or o == null or _.isNumber(o) or _.isBoolean(o) or _.isString(o)

ObjectBrowserEntryComponent = React.createClass
  displayName: 'ObjectBrowserEntryComponent'
  mixins: [Toggleable]
  render: ->
    key = @props.key
    value = @props.value

    if @props.enumerable
      className = ''
    else
      className = ' non-enumerable-property'
    if isSimple value
      React.DOM.div {},
        React.DOM.div {style: display: 'inline-block', verticalAlign: 'top', marginRight: '0.5em'},
          # spacer lol
          React.DOM.i {className: "fa fa-fw"}
          React.DOM.span {className: 'cm-variable' + className}, key
          React.DOM.span {className: 'cm-punctuation'}, ':'
        React.DOM.div {style: display: 'inline-block'},
          ObjectBrowserSummaryComponent object: value
    else
      React.DOM.div {},
        React.DOM.div {onClick: @toggle},
          React.DOM.div {style: display: 'inline-block', verticalAlign: 'top', marginRight: '0.5em'},
            React.DOM.i {className: "fa fa-fw #{@toggleClass()}"}
            React.DOM.span {className: 'cm-variable' + className}, key
            React.DOM.span {className: 'cm-punctuation'}, ':'
          React.DOM.div {style: display: 'inline-block'},
            ObjectBrowserSummaryComponent object: value
        if @state.open
          React.DOM.div {},
            # spacer lol
            React.DOM.i {className: "fa fa-fw"}
            ObjectBrowserEntriesComponent object: value, showProto: @props.showProto

componentForObject = (o) ->
  if _.isUndefined o
    React.DOM.span {className: "cm-atom"}, 'undefined'
  else if o == null
    React.DOM.span {className: "cm-atom"}, 'null'
  else if _.isNumber(o)
    React.DOM.span {className: "cm-number"}, o
  else if _.isBoolean(o)
    React.DOM.span {className: "cm-atom"}, if o then 'true' else 'false'
  else if _.isString o
    React.DOM.span {className: "cm-string", style: whiteSpace: 'pre'}, '"', o, '"'
  else if o instanceof Date
    React.DOM.span {}, o.toString()
  else
    null

ObjectBrowserSummaryComponent = React.createClass
  displayName: 'ObjectBrowserSummaryComponent'
  render: ->
    c = componentForObject @props.object
    if c?
      c
    else
      name = @props.object.constructor?.name
      if !name? or name == ''
        name = '(anonymous constructor)'
      if _.isArray @props.object
        name += "[#{@props.object.length}]"
      React.DOM.span {className: 'cm-variable'}, name

module.exports.ObjectBrowserComponent = ObjectBrowserComponent
