# TODO persist allNames

colors = require './colors'
d3 = require 'd3'
_ = require 'underscore'
moment = require 'moment'
Bacon = require 'bacon.model'
Q = require 'q'
React = require('react')
Components = require('./components')

{expandIsolatedValuesToLineSegments, simplifyPoints, transformData, computeSizes, targetValueAtTime} = require('./graph/utils')
BrushComponent = require('./graph/brushComponent')
LegendComponent = require('./graph/legendComponent')
CursorPositionMixin = require('./graph/cursorPositionMixin')
AxisComponent = require('./graph/axisComponent')
CrosshairComponent = require('./graph/crosshairComponent')

# jump through some hoops to add clip-path since SVGDOMPropertyConfig is useless
MUST_USE_ATTRIBUTE = require('react/lib/DOMProperty').MUST_USE_ATTRIBUTE
require('react/lib/ReactInjection').DOMProperty.injectDOMPropertyConfig
  Properties: clipPath: MUST_USE_ATTRIBUTE
  DOMAttributeNames: clipPath: 'clip-path'


clearExtent = (v) -> _.extend {}, v, {extent: null}
setBrushing = (v) -> _.extend {}, v, {brushing: true}
setNotBrushing = (v) -> _.extend {}, v, {brushing: false}

commaInt = d3.format(',.f')
commaDec = d3.format(',.3f')

valueFormat = (n) ->
  if n % 1 == 0
    commaInt(n)
  else
    commaDec(n)

defaultParams =
  width: 800
  height: 400
  type: 'line'
  getValue: (dp) -> dp[1]
  getTimestamp: (dp) -> dp[0]
  d3_colors: colors.d3.category10
  areaAlpha: null
  lineAlpha: null
  pointAlpha: null
  alpha: 1.0
  bgcolor: '#fff'
  areaMode: 'none'
  areaOffset: 'zero'
  drawNullAsZero: false
  simplify: 0.5
  axisLineColor: '#ccc'
  axisTextColor: '#aaa'
  axisTextSize: '10px'
  crosshairLineColor: '#ddd'
  crosshairTextColor: '#aaa'
  crosshairTextSize: '10px'
  crosshairValueTextColor: '#aaa'
  brushColor: '#efefef'
  valueFormat: valueFormat
  hideAxes: false
  hideLegend: false
  hideXAxis: false
  hideYAxis: false
  title: null
  titleTextSize: '12px'
  titleTextColor: '#333'
  legendTextColor: '#333'
  legendText: (d) -> d.name
  deselectedOpacity: 0.5
  lineWidth: 1
  drawAsInfinite: false
  radius: 2
  fixedHeight: false
  legendMaxHeight: null
  xAxisTicks: 10
  yAxisTicks: 10
  lineOpacity: 1.0

fgColorParams = [
  'axisLineColor',
  'axisTextColor',
  'crosshairLineColor',
  'crosshairTextColor',
  'titleTextColor',
  'legendTextColor'
]

pathStyles =
  line:
    fill: 'none'
    'stroke-linecap': 'square'

computeParams = (params) ->
  if params?.fgcolor
    computedParams = _.object _.map fgColorParams, (k) -> [k, params.fgcolor]
  else
    computedParams = {}
  _.extend {}, defaultParams, computedParams, params


LineComponent = React.createClass
  contextTypes:
    clipPath: React.PropTypes.string.isRequired

  propTypes:
    target: React.PropTypes.object.isRequired
    hover: React.PropTypes.bool
    highlighted: React.PropTypes.bool

  render: ->
    d = @props.target
    {clipPath} = @context

    if @props.hover
      extraWidth = 10
    else
      extraWidth = 0

    if @props.highlighted
      extraWidth += 3

    style = _.extend {'stroke-width': d.lineWidth + extraWidth, 'stroke-opacity': d.lineAlpha, 'fill-opacity': d.areaAlpha}, pathStyles[d.lineMode]

    <path stroke={d.color}
          style={style}
          fill={if d.lineMode is 'area' then d.color}
          d={d.lineFn(d.lineValues)}
          clipPath={clipPath}/>


ScatterComponent = React.createClass
  contextTypes:
    yScale: React.PropTypes.func.isRequired

  propTypes:
    target: React.PropTypes.object.isRequired
    hover: React.PropTypes.bool
    highlighted: React.PropTypes.bool

  render: ->
    d = @props.target
    {yScale} = @context
    [max, min] = yScale.range()

    if @props.hover
      extraRadius = 3
    else
      extraRadius = 0

    if @props.highlighted
      extraRadius += 3

    circleColor = d.color
    radius = d.radius + extraRadius

    circles = _.map d.scatterValues, (v, i) ->
      if v.y < min or v.y > max
        null
      else
        <circle key={i}
                cx={v.x}
                cy={v.y}
                fill={circleColor}
                r={radius}
                style={'fill-opacity': d.pointAlpha}/>

    <g>{circles}</g>


InfiniteLinesComponent = React.createClass
  propTypes:
    target: React.PropTypes.object.isRequired
    hover: React.PropTypes.bool
    highlighted: React.PropTypes.bool

  contextTypes:
    sizes: React.PropTypes.object.isRequired

  render: ->
    d = @props.target

    if @props.hover
      extraWidth = 10
    else
      extraWidth = 0

    if @props.highlighted
      extraWidth += 3

    lineColor = d.color
    lineWidth = d.lineWidth + extraWidth

    height = @context.sizes.height

    lines = _.map d.scatterValues, (v, i) ->
      # TODO filter earlier
      if v.value
        <line key={i}
              x1={v.x}
              x2={v.x}
              y1={0}
              y2={height}
              stroke={lineColor}
              style={{'stroke-opacity': d.lineAlpha, 'stroke-width': lineWidth}}/>

    <g>{lines}</g>


CrosshairValuePointComponent = React.createClass
  mixins: [CursorPositionMixin]

  propTypes:
    target: React.PropTypes.object.isRequired

  contextTypes:
    params: React.PropTypes.object.isRequired
    yScale: React.PropTypes.func.isRequired

  render: ->
    {params, yScale} = @context
    {target} = @props
    [max, min] = yScale.range()

    if target.type == 'scatter'
      radius = target.radius + 3
    else
      radius = 4

    if @state.value
      d = @state.value.targetValues[target.index]
      if d.y < min or d.y > max
        null
      else
        visibility = if d.value? then 'visible' else 'hidden'

        <circle
          fill={target.color}
          stroke={params.bgcolor}
          style={{'stroke-width': 2, visibility}}
          cx={d.x}
          cy={d.y}
          r={radius}/>
    else
      null


TargetComponent = React.createClass
  mixins: [Components.ObservableMixin]

  propTypes:
    target: React.PropTypes.object.isRequired
    hover: React.PropTypes.bool

  contextTypes:
    params: React.PropTypes.object.isRequired
    targetState: React.PropTypes.object.isRequired

  getObservable: (props, context) -> context.targetState

  render: ->
    {params} = @context
    d = @props.target

    {drawAsInfinite, type} = d

    selected = @state.value.selection[d.index]
    highlighted = @state.value.highlightIndex == d.index

    dataHandler = if drawAsInfinite
      InfiniteLinesComponent
    else if type is 'line'
      LineComponent
    else
      ScatterComponent

    opacity = if @props.hover
       0
    else if selected
      1
    else
      params.deselectedOpacity

    dataComponent = <dataHandler target={d} hover={@props.hover} highlighted={highlighted}/>

    if @props.hover
      <g style={{opacity}}>
        {dataComponent}
      </g>
    else
      <g style={{opacity}}>
        {dataComponent}
        <CrosshairValuePointComponent target={d}/>
      </g>


GraphComponent = React.createClass
  propTypes:
    params: React.PropTypes.object
    data: React.PropTypes.array

  getInitialState: ->
    @mousePosition = new Bacon.Bus
    @targetState = new Bacon.Model

    @getUpdatedState(@props)

  getUpdatedState: (props) ->
    _.each @destroyFunctions, (f) -> f()
    @destroyFunctions = []

    if props.params
      data = props.data ? []
      params = computeParams(props.params)
      sizes = computeSizes(data, params)

      {targets, xScale, yScale} = transformData(data, params, sizes)

      cursorModel = params.cursor ? new Bacon.Model
      brushModel = params.brush ? new Bacon.Model brushing: false

      @targetState.set({selection: _.map(targets, -> true), highlightIndex: null})

      cursorBus = new Bacon.Bus

      cursorBus.plug(@mousePosition.map((p) -> p.time))

      @destroyFunctions.push((-> cursorBus.end()))

      externalCursorChanges = cursorModel.addSource(cursorBus)
      boundedExternalCursorPosition = externalCursorChanges.map (time) ->
        domain = xScale.domain()
        if time < domain[0]
          time = domain[0]
        else if time > domain[1]
          time = domain[1]

        {x: xScale(time), time}

      cursorPosition = boundedExternalCursorPosition.merge(@mousePosition).map ({x, time}) ->
        targetValues = _.map targets, (t) -> targetValueAtTime(t, time)
        {x, time, targetValues}

      {targets, xScale, yScale, params, sizes, cursorPosition, brushModel}
    else
      {}

  componentWillReceiveProps: (props) ->
    @setState(@getUpdatedState(props))

  onMouseMove: (e) ->
    d3.event = e.nativeEvent
    try
      pos = d3.mouse(@refs.chartArea.getDOMNode())
      if pos[1] >= 0 and pos[1] <= @state.sizes.height
        xConstrained = Math.max 0, Math.min(pos[0], @state.sizes.width)

        @mousePosition.push
          time: @state.xScale.invert xConstrained
          value: @state.yScale.invert pos[1]
          x: xConstrained
          y: pos[1]
    finally
      d3.event = null

  onTargetClick: (target) ->
    @targetState.modify (m) ->
      m = _.clone(m)
      m.selection[target.index] = !m.selection[target.index]
      m

  onTargetMouseOver: (target) ->
    @targetState.modify (m) ->
      m = _.clone(m)
      m.highlightIndex = target.index
      m

  onTargetMouseOut: (target) ->
    @targetState.modify (m) ->
      m = _.clone(m)
      m.highlightIndex = null
      m

  childContextTypes:
    sizes: React.PropTypes.object
    params: React.PropTypes.object
    xScale: React.PropTypes.func
    yScale: React.PropTypes.func
    cursorPosition: React.PropTypes.object
    targetState: React.PropTypes.object
    clipPath: React.PropTypes.string

  getChildContext: ->
    context = _.pick(@state, Object.keys(@constructor.childContextTypes))
    context.targetState = @targetState
    context.clipPath = "url(#clipper)"
    context

  exportImage: ->
    svg = @refs.svg.getDOMNode()

    deferred = Q.defer()
    canvas = document.createElement('canvas')
    rect = svg.getBoundingClientRect()
    canvas.width = rect.width
    canvas.height = rect.height
    ctx = canvas.getContext('2d')
    svgString = new XMLSerializer().serializeToString(svg)
    svgBlob = new Blob([svgString], {type: 'image/svg+xml;charset=utf-8'})
    url = URL.createObjectURL(svgBlob)
    img = new Image
    img.src = url
    img.onload = ->
      ctx.drawImage(img, 0, 0)
      # would like to return a blob, but https://code.google.com/p/chromium/issues/detail?id=67587
      dataUrl = canvas.toDataURL()
      deferred.resolve(dataUrl)
    img.onerror = (e) ->
      deferred.reject(e)
    deferred.promise.finally ->
      URL.revokeObjectURL(url)

  render: ->
    if @state.params
      {targets, params, sizes, xScale, yScale} = @state

      if params.title?
        title = <text
                  key="title"
                  x={sizes.margin.left + sizes.width / 2}
                  y={10}
                  dy={params.titleTextSize}
                  fill={params.titleTextColor}
                  style={'font-size': params.titleTextSize, 'font-weight': 'bold'}>{params.title}</text>

      unless params.hideXAxis or params.hideAxes
        xAxis = <g key="xAxis" transform={"translate(0, #{sizes.height})"}>
          <AxisComponent axis={d3.svg.axis().scale(xScale).orient('bottom').ticks(params.xAxisTicks)}/>
        </g>

      unless params.hideYAxis or params.hideAxes
        yAxis = <g key="yAxis">
          <AxisComponent axis={d3.svg.axis().scale(yScale).orient('left').ticks(params.yAxisTicks)}/>
        </g>

      plots = _.map targets, (d, i) =>
        # TODO should have a better key
        <g key={i} onClick={=> @onTargetClick(d)} onMouseOver={=> @onTargetMouseOver(d)} onMouseOut={=> @onTargetMouseOut(d)}>
          <TargetComponent target={d} hover={false}/>
          <TargetComponent target={d} hover={true}/>
        </g>

      unless params.hideLegend
        legend = <LegendComponent targets={targets} mouseHandler={@}/>

      # react doesn't support clipPath :(
      clipper = """
      <clipPath id="clipper">
          <rect width="#{sizes.width}" height="#{sizes.height}"/>
      </clipPath>"""

      svg =
        <svg width={sizes.svgWidth} height={sizes.svgHeight}
          ref='svg'
          style={{'font-family': '"Helvetica Neue"', cursor: 'default', 'background-color': params.bgcolor}}
          onMouseMove={@onMouseMove}>
          {title}
          <g dangerouslySetInnerHTML={__html: clipper}/>

          <g transform={"translate(#{sizes.margin.left},#{sizes.margin.top})"} ref="chartArea">
            {xAxis}
            {yAxis}
            <CrosshairComponent/>
            <BrushComponent brushModel={@state.brushModel}/>
            <g key="targets">{plots}</g>
            {legend}
          </g>
        </svg>
    <div className="graph">
      {svg}
    </div>


module.exports = {GraphComponent}
