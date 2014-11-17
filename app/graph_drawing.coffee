colors = require './colors'
d3 = require 'd3'
_ = require 'underscore'
moment = require 'moment'
Bacon = require 'bacon.model'
Q = require 'q'

clearExtent = (v) -> _.extend {}, v, {extent: null}
setBrushing = (v) -> _.extend {}, v, {brushing: true}
setNotBrushing = (v) -> _.extend {}, v, {brushing: false}

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

invisibility = (sel, invisible) ->
  if invisible
    sel.attr('visibility', 'hidden')
  else
    sel.attr('visibility', 'visible')

defaultParams =
  width: 800
  height: 400
  type: 'line'
  get_value: (dp) -> dp[1]
  get_timestamp: (dp) -> dp[0]
  d3_colors: colors.d3.category10
  areaAlpha: 1.0
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
  valueFormat: d3.format(',.4g')
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
  #lineWidth: 1

fgColorParams = ['axisLineColor', 'axisTextColor', 'crosshairLineColor', 'crosshairTextColor', 'titleTextColor', 'legendTextColor']

pathStyles =
  line:
    fill: 'none'
    'stroke-linecap': 'square'

create = (container) ->
  x = d3.time.scale()
  y = d3.scale.linear()
  xAxis = d3.svg.axis().scale(x).orient('bottom')
  yAxis = d3.svg.axis().scale(y).orient('left')

  color = d3.scale.ordinal()

  mouseOver = new Bacon.Bus
  mouseOut = new Bacon.Bus
  clicks = new Bacon.Bus
  mouseMoves = new Bacon.Bus

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

  svg = d3.select(container)
    .append('svg')
    .style({'font-family': '"Helvetica Neue"', cursor: 'default'})
    .on('mousemove', (d, i) -> mouseMoves.push d3.mouse g.node())

  title = svg.append('text')
    .style('text-anchor', 'middle')

  # TODO font
  g = svg
    .append("g")

  xAxisG = g.append('g')
    .attr('class', 'x axis')

  yAxisG = g.append('g')
    .attr('class', 'y axis')

  verticalCrosshair = g.append('line')
    .attr('class', 'crosshair')
    .style('shape-rendering': 'crispEdges')
    .attr('y1', 0)

  crosshairTime = g.append('text')
    .style('text-anchor', 'middle')
    .attr('y', -6)

  brushG = g.append("g")
    .attr("class", "x brush")

  legendG = g.append("g")
    .attr("class", "legend")

  currentCrosshairTime = null
  allNames = []

  destroyFunctions = []
  destroy = ->
    _.each(destroyFunctions, (f) -> f())
    destroyFunctions = []

  exportImage = ->
    deferred = Q.defer()
    canvas = document.createElement('canvas')
    rect = svg.node().getBoundingClientRect()
    canvas.width = rect.width
    canvas.height = rect.height
    ctx = canvas.getContext('2d')
    svgString = new XMLSerializer().serializeToString(svg.node())
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

  draw = (data, params) ->
    destroy()
    if params?.fgcolor
      computedParams = _.object _.map fgColorParams, (k) -> [k, params.fgcolor]
    else
      computedParams = {}
    params = _.extend {}, defaultParams, computedParams, params
    width = params.width
    height = params.height

    legendRowHeight = 18

    cursorModel = params.cursor ? new Bacon.Model
    brushModel = params.brush ? new Bacon.Model brushing: false

    cursorBus = new Bacon.Bus
    brushBus = new Bacon.Bus

    destroyFunctions.push((-> cursorBus.end()), (-> brushBus.end()))

    externalCursorChanges = cursorModel.addSource cursorBus
    externalBrushChanges = brushModel.apply brushBus

    type = params.type

    margin = top: 20, right: 80, bottom: 10, left: 80
    if params.title
      margin.top += 30


    width -= margin.left + margin.right
    height -= margin.top + margin.bottom

    x.range([0, width])
    y.range([height, 0])

    get_value = params.get_value
    get_timestamp = params.get_timestamp

    color.range params.d3_colors
    # ensure that colors are stable even if targets change position in the list
    allNames = _.uniq(allNames.concat(_.pluck(data, 'target')...))
    colorsByName = {}
    _.each allNames, (name, i) ->
      colorsByName[name] = color(i)

    observeMouse = (s) ->
      s.on('mouseover', (d, i) -> mouseOver.push {index: i, event: d3.event, data: d})
      .on('mouseout', (d, i) -> mouseOut.push {index: i, event: d3.event, data: d})
      .on('click', (d, i) -> clicks.push i)

    selected = clicks.scan _.map(data, -> true), (state, i) ->
      newState = _.clone state
      newState[i] = !newState[i]
      newState

    hoverSelections = mouseOver.map ({index}) -> {index, selection: d3.select(container).selectAll ".target#{index}"}
    hoverSelections.onValue ({selection, index}) ->
      if type == 'line'
        path = selection.select('path')
        path.style('stroke-width', (params.lineWidth ? 0) + 3)
      else
        circles = selection.select('.circles').selectAll('circle')
        circles.attr('r', 4)
      highlightLegend(index)
    unhovers = hoverSelections.merge(mouseOut)
      .withStateMachine([], (previous, event) -> [[event], previous])
      .filter (e) -> e.selection?
    unhovers.onValue ({selection, index}) ->
      highlightLegend(null)
      if type == 'line'
        path = selection.select('path')
        path.style('stroke-width', params.lineWidth)
      else
        circles = selection.select('.circles').selectAll('circle')
        circles.attr('r', 2)

    mousePosition = mouseMoves.map (pos) ->
      xConstrained = Math.max 0, Math.min(pos[0], width)
      time: x.invert xConstrained
      value: y.invert pos[1]
      x: xConstrained
      y: pos[1]

    timeMin = null
    timeMax = null
    _.each data, ({datapoints}, j) ->
      if datapoints.length > 0
        _.each [0, datapoints.length - 1], (i) ->
          datapoint = datapoints[i]
          value = get_value datapoint, i, j
          timestamp = get_timestamp datapoint, i, j
          timeMin = Math.min timestamp, timeMin ? timestamp
          timeMax = Math.max timestamp, timeMax

    timeMin = new Date(timeMin * 1000)
    timeMax = new Date(timeMax * 1000)
    x.domain [params.xMin ? timeMin, params.xMax ? timeMax]

    stack.offset(params.areaOffset)

    if type is 'line'
      areaOpacity = params.areaAlpha
      lineOpacity = 1.0

      if params.interpolate?
        line.interpolate params.interpolate
        area.interpolate params.interpolate

    if params.simplify
      simplify = _.partial simplifyPoints, params.simplify
    else
      simplify = _.identity

    if params.drawNullAsZero
      transformValue = (v) -> v ? 0
      filterScatterValues = simplify
      expandLineValues = simplify
    else
      # TODO this won't work well with stack
      transformValue = (v) -> v
      filterScatterValues = (values) ->
        simplify _.filter values, (d) -> d.value?
      expandLineValues = _.compose expandIsolatedValuesToLineSegments, simplify

    valueMin = null
    valueMax = null
    targets = for s, targetIndex in data
      values = for datapoint, i in s.datapoints
        value = get_value datapoint, i, targetIndex
        timestamp = get_timestamp datapoint, i, targetIndex
        time = new Date(timestamp * 1000)
        value = transformValue value
        valueMin = Math.min value, valueMin ? value if value?
        valueMax = Math.max value, valueMax
        {value, time: time, x: x(time), original: datapoint}
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
      targetColor = colorsByName[name]
      {values, bisector, name, lineMode, lineFn, color: targetColor}

    if params.areaMode is 'stacked'
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
    y.domain [params.yMin ? valueMin, params.yMax ? valueMax]

    _.each targets, (target) ->
      {values} = target
      _.each values, (v) ->
        if v.value?
          v.y = y v.value
      target.lineValues = expandLineValues values
      target.scatterValues = filterScatterValues values

    g
      .attr("transform", "translate(#{margin.left},#{margin.top})")

    title
      .attr('x', margin.left + width / 2)
      .attr('y', 10)
      .attr('dy', params.titleTextSize)
      .attr('fill', params.titleTextColor)
      .text(params.title)
      .style('font-size': params.titleTextSize, 'font-weight': 'bold')
    invisibility(title, !params.title?)

    xAxisG
      .attr('transform', "translate(0, #{height})")
      .call(xAxis)
    invisibility(xAxisG, params.hideXAxis or params.hideAxes)

    yAxisG.call(yAxis)
    invisibility(yAxisG, params.hideYAxis or params.hideAxes)

    axes = g.selectAll('.axis')

    axes.selectAll('path, line').attr('stroke', params.axisLineColor).attr({'fill': 'none', 'shape-rendering': 'crispEdges'})
    axes.selectAll('text').attr('fill', params.axisTextColor).style('font-size', params.axisTextSize)

    verticalCrosshair
      .attr('y2', height)
      .attr('stroke', params.crosshairLineColor)

    brushed = ->
      brushBus.push if brush.empty() then clearExtent else (v) -> _.extend {}, v, {extent: brush.extent()}
    brushstart = -> brushBus.push setBrushing
    brushend = -> brushBus.push setNotBrushing

    brush = d3.svg.brush()
      .x(x)
      .on("brush", brushed)
      .on('brushstart', brushstart)
      .on('brushend', brushend)

    brushG.call(brush)

    destroyFunctions.push externalBrushChanges.onValue ({extent}) ->
      if extent?
        domain = x.domain()
        brush.extent [Math.min(Math.max(domain[0], extent[0]), domain[1]), Math.max(Math.min(domain[1], extent[1]), domain[0])]
      else
        brush.clear()
      brush brushG

    brushG.selectAll("rect")
      .attr("y", 0)
      .attr("height", height)
      .attr('fill', params.brushColor)

    positionCrosshair = (x, time) ->
      currentCrosshairTime = time
      verticalCrosshair
        .attr('x1', x)
        .attr('x2', x)

      crosshairTime
        .text(moment(time).format('lll'))
        .attr('x', x)
        .attr('fill', params.crosshairTextColor)
        .style('font-size': params.crosshairTextSize)

      targetValues = _.map targets, (t) ->
        i = t.bisector.left t.values, time, 1
        d0 = t.values[i - 1]
        d1 = t.values[i]
        if d0 and d1
          if time - d0.time > d1.time - time then d1 else d0
        else if d0
          d0

      legendG.selectAll('.crosshair-value')
        .data(targetValues)
        .text((d) -> params.valueFormat(d?.value))


    mousePosition.onValue (p) ->
      positionCrosshair p.x, p.time
      cursorBus.push p.time

    boundedPositionCrosshair = (time) ->
      domain = x.domain()
      if time < domain[0]
        time = domain[0]
      else if time > domain[1]
        time = domain[1]
      positionCrosshair x(time), time

    if currentCrosshairTime?
      boundedPositionCrosshair(currentCrosshairTime)
    # TODO if the mouse is over the graph, use that position so it doesn't jump

    destroyFunctions.push externalCursorChanges.onValue (time) ->
      boundedPositionCrosshair(time)

    target = g.selectAll('.target')
      .data(targets)
    target.enter().append("g")
      .attr('class', (d, i) -> "target target#{i}")
      .call(observeMouse)
    target.exit().remove()
    target.selectAll('g > *').remove()


    addPath = (target, hover) ->
      if hover
        lineWidth = (params.lineWidth ? 0) + 10
      else
        lineWidth = params.lineWidth

      path = target.append("path")
        .attr('class', (d) -> d.lineMode)
        .attr('stroke', (d, i) -> d.color)
        .style('stroke-width', lineWidth)
        .attr('fill', (d, i) -> if d.lineMode is 'area' then d.color)
        # TODO don't call lineFn for both visible and hover paths
        .attr('d', (d, i) -> d.lineFn(d.lineValues))
        .each((d) -> d3.select(@).style(pathStyles[d.lineMode]))
      if hover
        path
          .style('stroke-opacity', 0)
          .style('fill-opacity', 0)
      else
        path
          .style('stroke-opacity', lineOpacity)
          .style('fill-opacity', areaOpacity)

    addCircles = (target, hover) ->
      if hover
        radius = 5
        opacity = 0
      else
        radius = 2
        opacity = 1
      target.append('g').attr('class', 'circles')
      .each (d) ->
        circleColor = d.color
        d3.select(this).selectAll('circle')
        .data((d) -> d.scatterValues)
        .enter().append("circle")
        .attr('cx', (d) -> d.x)
        .attr('cy', (d) -> y d.value)
        .attr('fill', circleColor)
        .attr('r', radius)
        .style('fill-opacity', opacity)

    if type is 'line'
      addPath target, false
      addPath target, true
    else if type is 'scatter'
      addCircles target, false
      addCircles target, true

    invisibility(legendG, params.hideLegend)
    legendFontSize = '11px'
    legendG.attr('transform', "translate(0,#{height + 30})")

    legendGTarget = legendG.selectAll('g').data(targets)
    legendGTarget.enter()
      .append('g')
      .attr('transform', (d, i) -> "translate(0,#{i * legendRowHeight})")
      .call(observeMouse)
      .each (d, i) ->
        item = d3.select(@)

        item.append('rect')
          .attr('x', 4)
          .attr('y', 4)
          .attr('width', '6px')
          .attr('height', '6px')
        text = item.append('text')
          .attr('x', 16)
          .attr('dy', legendFontSize)
          .style('font-size', legendFontSize)
        text.append('tspan').attr('class', 'legend-name')
        text.append('tspan').style('white-space': 'pre').text('   ')
        text.append('tspan').attr('class', 'crosshair-value')

    legendGTarget.select('.legend-name')
      .text(params.legendText)
      .attr('title', (d) -> d.name)
      .attr('fill', params.legendTextColor)
    legendGTarget.select('.crosshair-value')
      .attr('fill', params.crosshairValueTextColor)
    legendGTarget.select('rect')
      .attr('fill', (d, i) -> d.color)

    legendGTarget.exit().remove()

    if !params.hideLegend
      svgHeight = height + margin.top + margin.bottom + targets.length * legendRowHeight + 30
    else
      svgHeight = height + margin.top + margin.bottom + 30
    svg
      .attr('width', width + margin.left + margin.right)
      .attr('height', svgHeight)
      .style('background-color', params.bgcolor)

    highlightLegend = (highlightIndex) ->
      legendGTarget.selectAll('rect').each (d, i, j) ->
        rect = d3.select(this)
        if j == highlightIndex
          rect
            .attr('x', 2)
            .attr('y', 2)
            .attr('width', 10)
            .attr('height', 10)
        else
          rect
            .attr('x', 4)
            .attr('y', 4)
            .attr('width', '6px')
            .attr('height', '6px')

    selectLegend = (selections) ->
      legendGTarget.attr 'opacity', (d, i) ->
        if selections[i] then 1 else 0.5

    selected.onValue (s) ->
      selectLegend(s)
      g.selectAll('.target').attr 'opacity', (d, i) ->
        if s[i] then 1 else params.deselectedOpacity

  {draw, exportImage, destroy}

module.exports = {create}
