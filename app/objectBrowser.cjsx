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

Spacer = <i className="fa fa-fw"/>

Var = React.createClass
  render: -> <span className="cm-variable">{@props.children}</span>

Punct = React.createClass
  render: -> <span className="cm-punctuation">{@props.children}</span>


ObjectBrowserComponent = React.createClass
  getDefaultProps: ->
    showProto: true

  childContextTypes:
    showProto: React.PropTypes.bool.isRequired

  getChildContext: ->
    showProto: @props.showProto

  render: ->
    browser = if isSimple(@props.object)
      componentForObject(@props.object)
    else if _.isArray(@props.object)
      <ObjectBrowserTopLevelArrayComponent object={@props.object}/>
    else
      <ObjectBrowserTopLevelObjectComponent object={@props.object}/>

    <div className='object-browser'>{browser}</div>


TopLevelComponent = React.createClass
  mixins: [Toggleable]

  render: ->
    inside = if @state.open
      <div>
        {Spacer}
        <ObjectBrowserEntriesComponent object={@props.object}/>
      </div>

    <div>
      <div onClick={@toggle}>
        <i className={"fa fa-fw #{@toggleClass()}"}/>
        {@props.children}
      </div>
      {inside}
    </div>


ObjectBrowserTopLevelObjectComponent = React.createClass
  render: ->
    {object} = @props

    # TODO only ownProperties
    children = _.map Object.keys(object)[..5], (key) =>
      try
        child = <ObjectBrowserSummaryComponent object={object[key]}/>
      catch e
        child = '(error in getter)'

      <span>
        <Var>{key}</Var>
        <Punct>: </Punct>
        {child}
      </span>

    <TopLevelComponent object={object}>
      <span>
        <Var>Object </Var>
        <Punct>{'{'}</Punct>
        {_.intersperse children, <Punct>, </Punct>}
        <Punct>{'}'}</Punct>
      </span>
    </TopLevelComponent>


ObjectBrowserTopLevelArrayComponent = React.createClass
  render: ->
    children = _.map @props.object[...20], (v) ->
      <ObjectBrowserSummaryComponent object={v}/>

    <TopLevelComponent object={@props.object}>
      <span>
        <Punct>[</Punct>
        {_.intersperse children, <Punct>, </Punct>}
        <Punct>]</Punct>
      </span>
    </TopLevelComponent>


ObjectBrowserEntriesComponent = React.createClass
  contextTypes:
    showProto: React.PropTypes.bool.isRequired

  getInitialState: ->
    visibleEntries: 50

  expand: (e) ->
    e.stopPropagation()
    @setState visibleEntries: @state.visibleEntries * 2

  render: ->
    {object} = @props
    proto = Object.getPrototypeOf(object)
    propertyNames = _.without(Object.getOwnPropertyNames(object), '__proto__')

    children = _.map propertyNames[...@state.visibleEntries], (key) =>
      try
        value = object[key]
      catch e
        value = null

      enumerable = Object.getOwnPropertyDescriptor(object, key).enumerable
      <ObjectBrowserEntryComponent key={key} value={value} enumerable={enumerable}/>

    showMore = if propertyNames.length > @state.visibleEntries
      <div onClick={@expand} className='run-button'>Show more</div>

    protoChild = if proto? and @context.showProto
      <ObjectBrowserEntryComponent key='__proto__' value={proto} own={false}/>

    <div style={display: 'inline-block'}>
      {children}
      {showMore}
      {protoChild}
    </div>


isSimple = (o) ->
  return (!o?) or o == null or _.isNumber(o) or _.isBoolean(o) or _.isString(o)

ObjectBrowserEntryComponent = React.createClass
  mixins: [Toggleable]

  render: ->
    {key, value, enumerable} = @props

    if enumerable
      className = ''
    else
      className = 'non-enumerable-property'

    summary = 
      <div style={display: 'inline-block'}>
        <ObjectBrowserSummaryComponent object={value}/>
      </div>

    if isSimple value
      <div>
        <div style={display: 'inline-block', verticalAlign: 'top', marginRight: '0.5em'}>
          {Spacer}
          <span className={className}><Var>{key}</Var><Punct>:</Punct></span>
        </div>
        {summary}
      </div>
    else
      inside = if @state.open
        <div>
          {Spacer}
          <ObjectBrowserEntriesComponent object={value}/>
        </div>

      <div>
        <div onClick={@toggle}>
          <div style={display: 'inline-block', verticalAlign: 'top', marginRight: '0.5em'}>
            <i className={"fa fa-fw #{@toggleClass()}"}/>
            <span className={className}><Var>{key}</Var><Punct>:</Punct></span>
          </div>
          {summary}
        </div>
        {inside}
      </div>

componentForObject = (o) ->
  if _.isUndefined(o)
    <span className="cm-atom">undefined</span>
  else if o == null
    <span className="cm-atom">null</span>
  else if _.isNumber(o)
    <span className="cm-number">{o}</span>
  else if _.isBoolean(o)
    <span className="cm-atom">{if o then 'true' else 'false'}</span>
  else if _.isString(o)
    <span className="cm-string" style={whiteSpace: 'pre'}>"{o}"</span>
  else if o instanceof Date
    <span>{o.toString()}</span>
  else
    null

ObjectBrowserSummaryComponent = React.createClass
  displayName: 'ObjectBrowserSummaryComponent'
  render: ->
    c = componentForObject(@props.object)
    if c?
      c
    else
      name = @props.object.constructor?.name
      if !name? or name == ''
        name = '(anonymous constructor)'
      if _.isArray(@props.object)
        name += "[#{@props.object.length}]"

      <Var>{name}</Var>

module.exports.ObjectBrowserComponent = ObjectBrowserComponent
