# TODO persist allNames

colors = require './colors'
d3 = require 'd3'
_ = require 'underscore'
moment = require 'moment'
Bacon = require 'bacon.model'
Q = require 'q'
React = require('react')
Components = require('./components')

# jump through some hoops to add clip-path since SVGDOMPropertyConfig is useless
MUST_USE_ATTRIBUTE = require('react/lib/DOMProperty').MUST_USE_ATTRIBUTE
require('react/lib/ReactInjection').DOMProperty.injectDOMPropertyConfig
  Properties: clipPath: MUST_USE_ATTRIBUTE
  DOMAttributeNames: clipPath: 'clip-path'


clearExtent = (v) -> _.extend {}, v, {extent: null}
setBrushing = (v) -> _.extend {}, v, {brushing: true}
setNotBrushing = (v) -> _.extend {}, v, {brushing: false}

# [1 2 null 3 null 4 5] -> [1 2 null 3 3 null 4 5]
expandIsolatedValuesToLineSegments = (values) ->
  result = []
  segmentLength = 0
  previous = null
  _.each values, (v, i) ->
    if v.value?
      segmentLength++
      previous = v
    else
      if segmentLength is 1
        result.push previous
      segmentLength = 0

    result.push v

  if segmentLength is 1
    result.push previous
  result

simplifyPoints = (minDistance, values) ->
  previous = null
  result = []

  _.each values, (v) ->
    if previous?
      if previous.y? != v.y? # discontinuity
        result.push v
        if v.y?
          previous = v
      else if v.y?
        deltaX = Math.abs v.x - previous.x
        deltaY = Math.abs v.y - previous.y
        if Math.sqrt(deltaX * deltaX + deltaY * deltaY) > minDistance
          previous = v
          result.push v
    else
      previous = v
      result.push v

  result

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

CursorPositionMixin = _.extend {}, Components.ObservableMixin,
  contextTypes:
    cursorPosition: React.PropTypes.object.isRequired

  get_observable: (props, context) -> context.cursorPosition

AxisComponent = React.createClass
  propTypes:
    axis: React.PropTypes.func.isRequired

  contextTypes:
    params: React.PropTypes.object.isRequired

  render: ->
    <g/>

  componentDidMount: ->
    @drawAxis()

  componentDidUpdate: ->
    @drawAxis()

  drawAxis: ->
    {params} = @context
    # FIXME empty dom node
    sel = d3.select(@getDOMNode())
    sel.call(@props.axis)

    sel.selectAll('path, line').attr('stroke', params.axisLineColor).attr({'fill': 'none', 'shape-rendering': 'crispEdges'})
    sel.selectAll('text').attr('fill', params.axisTextColor).style('font-size', params.axisTextSize)


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
  propTypes:
    target: React.PropTypes.object.isRequired
    hover: React.PropTypes.bool
    highlighted: React.PropTypes.bool

  render: ->
    d = @props.target

    if @props.hover
      extraRadius = 3
    else
      extraRadius = 0

    if @props.highlighted
      extraRadius += 3

    circleColor = d.color
    radius = d.radius + extraRadius

    circles = _.map d.scatterValues, (v, i) ->
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
  propTypes:
    target: React.PropTypes.object.isRequired

  mixins: [CursorPositionMixin]
  contextTypes:
    params: React.PropTypes.object.isRequired

  render: ->
    {params} = @context
    {target} = @props

    if target.type == 'scatter'
      radius = target.radius + 3
    else
      radius = 4

    if @state.value
      d = @state.value.targetValues[target.index]
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

  get_observable: (props, context) -> context.targetState

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


BrushComponent = React.createClass
  propTypes:
    brushModel: React.PropTypes.object.isRequired

  contextTypes:
    xScale: React.PropTypes.func.isRequired
    sizes: React.PropTypes.object.isRequired
    params: React.PropTypes.object.isRequired

  createBrush: ->
    d3.svg.brush()
      .x(@context.xScale)
      .on("brush", @onBrush)
      .on('brushstart', @onBrushStart)
      .on('brushend', @onBrushEnd)

  onBrush: ->
    brush = d3.event.target
    @brushBus.push if brush.empty() then clearExtent else (v) -> _.extend {}, v, {extent: brush.extent()}

  onBrushStart: ->
    @brushBus.push(setBrushing)

  onBrushEnd: ->
    @brushBus.push(setNotBrushing)

  setExtent: (context, extent) ->
    {xScale} = context
    domain = xScale.domain()

    if extent?
      @brush.extent([Math.min(Math.max(domain[0], extent[0]), domain[1]), Math.max(Math.min(domain[1], extent[1]), domain[0])])
    else
      @brush.clear()

    @selection.call(@brush)

  unsubscribe: ->
    @brushBus?.end()
    @brushModelUnsubscribe?()

  update: (props, context) ->
    {brushModel} = props
    @selection.selectAll("rect")
      .attr("y", 0)
      .attr("height", context.sizes.height)
      .attr('fill', context.params.brushColor)

    @brush.x(context.xScale)

    @setExtent(context, null)

    @unsubscribe()

    @brushBus = new Bacon.Bus

    externalChanges = brushModel.apply(@brushBus)
    @brushModelUnsubscribe = externalChanges.onValue ({extent}) =>
      @setExtent(context, extent)

  render: ->
    <g/>

  componentDidMount: ->
    @selection = d3.select(@getDOMNode())
    @brush = @createBrush()
    @selection.call(@brush)
    @update(@props, @context)

  componentWillReceiveProps: (props, context) ->
    @update(props, context)

  componentWillUnmount: ->
    @unsubscribe()


CrosshairComponent = React.createClass
  mixins: [CursorPositionMixin]

  contextTypes:
    params: React.PropTypes.object.isRequired
    sizes: React.PropTypes.object.isRequired

  render: ->
    if @state.value
      {params, sizes} = @context
      {height} = sizes

      {x, time} = @state.value

      <g>
        <line style={{'shape-rendering': 'crispEdges'}} x1={x} x2={x} y1={0} y2={height} stroke={params.crosshairLineColor}/>
        <text x={x} y="-6" fill={params.crosshairTextColor} style={{'text-anchor': 'middle', 'font-size': params.crosshairTextSize}}>{moment(time).format('lll')}</text>
      </g>
    else
      null


LegendCrosshairValueComponent = React.createClass
  mixins: [CursorPositionMixin]

  propTypes:
    target: React.PropTypes.object.isRequired

  contextTypes:
    params: React.PropTypes.object.isRequired

  render: ->
    {params} = @context
    {target} = @props

    if @state.value
      text = params.valueFormat(@state.value.targetValues[target.index]?.value)
    else
      text = ''

    <tspan fill={params.crosshairValueTextColor}>{text}</tspan>


LegendComponent = React.createClass
  mixins: [Components.ObservableMixin]

  propTypes:
    targets: React.PropTypes.array.isRequired
    mouseHandler: React.PropTypes.object.isRequired

  contextTypes:
    sizes: React.PropTypes.object.isRequired
    params: React.PropTypes.object.isRequired
    targetState: React.PropTypes.object.isRequired

  get_observable: -> @context.targetState

  render: ->
    {sizes, params} = @context

    {targets, mouseHandler} = @props

    legendEntries = _.map targets[...sizes.legendRowCount], (d, i) =>
      selected = @state.value.selection[d.index]
      highlighted = @state.value.highlightIndex == d.index

      if highlighted
        offset = 2
        size = 10
      else
        offset = 4
        size = 6

      opacity = if selected then 1 else params.deselectedOpacity

      <g key={i} opacity={opacity} transform={"translate(0,#{i * sizes.legendRowHeight})"} onClick={=> mouseHandler.onTargetClick(d)} onMouseOver={=> mouseHandler.onTargetMouseOver(d)} onMouseOut={=> mouseHandler.onTargetMouseOut(d)}>
        <rect x={offset} y={offset} width={size} height={size} fill={d.color}/>
        <text x="16" dy="11" style={'font-size': '11px'}>
          <tspan fill={params.legendTextColor}>{params.legendText(d)}</tspan>
          <tspan style={'white-space': 'pre'}>   </tspan>
          <LegendCrosshairValueComponent target={d}/>
        </text>
      </g>

    <g transform={"translate(0,#{sizes.height + 30})"}>{legendEntries}</g>


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


transformData = (data, params, sizes) ->
  color = d3.scale.ordinal().range(params.d3_colors)

  allNames = []
  # ensure that colors are stable even if targets change position in the list
  allNames = _.uniq(allNames.concat(_.pluck(data, 'target')...))
  colorsByName = {}
  _.each allNames, (name, i) ->
    colorsByName[name] = color(i)

  x = d3.time.scale()
  y = d3.scale.linear()

  x.range([0, sizes.width])
  y.range([sizes.height, 0])

  area = d3.svg.area()
    .x((d) -> d.x)
    .y0((d) -> y d.y0 ? 0)
    .y1((d) -> y d.value + (d.y0 ? 0))
    .defined((d) -> d.value?)

  line = d3.svg.line()
    .x((d) -> d.x)
    .y((d) -> y d.value)
    .defined((d) -> d.value?)

  stack = d3.layout.stack()
    .values((d) -> d.values)
    .x((d) -> d.time)
    .y((d) -> d.value)
    .out((d, y0, y) ->
      d.y0 = y0
      d.value = y)
    .offset(params.areaOffset)

  if params.interpolate?
    line.interpolate(params.interpolate)
    area.interpolate(params.interpolate)

  if params.simplify
    simplify = _.partial(simplifyPoints, params.simplify)
  else
    simplify = _.identity

  valueMin = null
  valueMax = null

  timeMin = null
  timeMax = null

  targets = for s, targetIndex in data
    options = _.extend {}, params, s.options
    {drawAsInfinite, getValue, getTimestamp, drawNullAsZero} = options
    if params.drawNullAsZero
      transformValue = (v) -> v ? 0
    else
      transformValue = (v) -> v
    values = for datapoint, i in s.datapoints
      value = transformValue(getValue(datapoint, i, targetIndex))
      timestamp = getTimestamp(datapoint, i, targetIndex)
      timeMin = Math.min(timestamp, timeMin ? timestamp)
      timeMax = Math.max(timestamp, timeMax)
      time = new Date(timestamp * 1000)
      unless drawAsInfinite
        valueMin = Math.min value, valueMin ? value if value?
        valueMax = Math.max value, valueMax ? value if value?
      {value, time: time, original: datapoint}
    bisector = d3.bisector (d) -> d.time
    lineMode =
      if params.areaMode is 'all' or params.areaMode is 'stacked'
        'area'
      else if params.areaMode is 'first' and targetIndex is 0
        'area'
      else
        'line'
    lineFn = if lineMode is 'line'
      line
    else
      area
    name = s.target
    targetColor = options.color ? colorsByName[name]
    areaAlpha = options.areaAlpha ? options.alpha
    lineAlpha = options.lineAlpha ? options.alpha
    pointAlpha = options.pointAlpha ? options.alpha
    _.extend options, {values, bisector, name, lineMode, lineFn, color: targetColor, index: targetIndex}


  timeMin = new Date(timeMin * 1000)
  timeMax = new Date(timeMax * 1000)

  if params.areaMode is 'stacked' and targets.length > 0
    stack targets
    valueMin = null
    valueMax = null
    for {values} in targets
      for {value, y0} in values
        value += y0
        valueMin = Math.min value, valueMin
        valueMax = Math.max value, valueMax

  if valueMin == valueMax
    valueMin = Math.round(valueMin) - 1
    valueMax = Math.round(valueMax) + 1

  y.domain([params.yMin ? valueMin, params.yMax ? valueMax])
  x.domain([params.xMin ? timeMin, params.xMax ? timeMax])

  _.each targets, (target) ->
    {values, drawNullAsZero} = target
    _.each values, (v) ->
      if v.value?
        v.y = y(v.value)
      v.x = x(v.time)

    if drawNullAsZero
      filterScatterValues = simplify
      expandLineValues = simplify
    else
      # TODO this won't work well with stack
      filterScatterValues = (values) ->
        simplify _.filter values, (d) -> d.value?

      expandLineValues = _.compose expandIsolatedValuesToLineSegments, simplify

    target.lineValues = expandLineValues values
    target.scatterValues = filterScatterValues values

  {targets, valueMin, valueMax, timeMin, timeMax, xScale: x, yScale: y}

computeSizes = (data, params) ->
  width = params.width
  height = params.height

  legendRowHeight = 18
  margin = top: 20, right: 80, bottom: 10, left: 80

  if params.title
    margin.top += 30

  width -= margin.left + margin.right
  height -= margin.top + margin.bottom

  legendCropped = false
  legendRowCount = data.length

  if !params.hideLegend
    if params.legendMaxHeight? and data.length * legendRowHeight > params.legendMaxHeight
      legendCropped = true
      legendRowCount = Math.floor(params.legendMaxHeight / legendRowHeight)
    legendHeight = legendRowCount * legendRowHeight
  else
    legendHeight = 0

  if params.fixedHeight
    height -= legendHeight

  svgWidth = width + margin.left + margin.right
  svgHeight = height + margin.top + margin.bottom + 30 + legendHeight

  {width, height, margin, svgWidth, svgHeight, legendRowCount, legendRowHeight, legendHeight}


targetValueAtTime = (target, time) ->
  i = target.bisector.left target.values, time, 1
  d0 = target.values[i - 1]
  d1 = target.values[i]
  if d0 and d1
    if time - d0.time > d1.time - time then d1 else d0
  else if d0
    d0

module.exports = {GraphComponent}
