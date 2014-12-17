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
  getValue: (dp) -> dp[1]
  getTimestamp: (dp) -> dp[0]
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
  lineWidth: 1
  drawAsInfinite: false
  radius: 2
  fixedHeight: false
  legendMaxHeight: null
  xAxisTicks: 10
  yAxisTicks: 10

seriesParams = [
  'lineWidth'
  'radius'
  'getValue'
  'getTimestamp'
  'drawNullAsZero'
  'drawAsInfinite'
  'type'
]

fgColorParams = ['axisLineColor', 'axisTextColor', 'crosshairLineColor', 'crosshairTextColor', 'titleTextColor', 'legendTextColor']

pathStyles =
  line:
    fill: 'none'
    'stroke-linecap': 'square'

create = (container) ->
  width = null
  height = null
  x = d3.time.scale()
  y = d3.scale.linear()
  xAxis = d3.svg.axis().scale(x).orient('bottom')
  yAxis = d3.svg.axis().scale(y).orient('left')

  color = d3.scale.ordinal()

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
    .on('mousemove', (d, i) ->
      pos = d3.mouse(g.node())
      if pos[1] >= 0 and pos[1] <= height
        mouseMoves.push pos
    )

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
    noData = !data?
    if noData
      data = []
      g.style('opacity', 0)
    else
      g.style('opacity', 1)

    destroy()

    mouseOver = new Bacon.Bus
    mouseOut = new Bacon.Bus
    clicks = new Bacon.Bus

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

    svgHeight = height + margin.top + margin.bottom + 30 + legendHeight

    svg
      .attr('width', width + margin.left + margin.right)
      .attr('height', svgHeight)
      .style('background-color', params.bgcolor)

    x.range([0, width])
    y.range([height, 0])

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
      selection.each (d) ->
        targetSelection = d3.select(this)

        targetSelection.select('path')
          .style('stroke-width', (d) -> d.lineWidth + 3)

        targetSelection.select('.infiniteLines').each (d) ->
          d3.select(this).selectAll('line')
            .style('stroke-width', d.lineWidth + 3)

        targetSelection.select('.circles').each (d) ->
          d3.select(this).selectAll('circle')
            .attr('r', d.radius + 3)

      highlightLegend(index)

    unhovers = hoverSelections.merge(mouseOut)
      .withStateMachine([], (previous, event) -> [[event], previous])
      .filter (e) -> e.selection?

    unhovers.onValue ({selection, index}) ->
      highlightLegend(null)

      selection.each (d) ->
        targetSelection = d3.select(this)

        targetSelection.select('path')
          .style('stroke-width', (d) -> d.lineWidth)

        targetSelection.select('.infiniteLines').each (d) ->
          d3.select(this).selectAll('line')
            .style('stroke-width', d.lineWidth)

        targetSelection.select('.circles').each (d) ->
          d3.select(this).selectAll('circle')
            .attr('r', d.radius)


    mousePosition = mouseMoves.map (pos) ->
      xConstrained = Math.max 0, Math.min(pos[0], width)
      time: x.invert xConstrained
      value: y.invert pos[1]
      x: xConstrained
      y: pos[1]

    stack.offset(params.areaOffset)

    areaOpacity = params.areaAlpha
    lineOpacity = 1.0

    if params.interpolate?
      line.interpolate params.interpolate
      area.interpolate params.interpolate

    if params.simplify
      simplify = _.partial simplifyPoints, params.simplify
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
          valueMax = Math.max value, valueMax
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
      _.extend options, {values, bisector, name, lineMode, lineFn, color: targetColor}


    timeMin = new Date(timeMin * 1000)
    timeMax = new Date(timeMax * 1000)
    x.domain [params.xMin ? timeMin, params.xMax ? timeMax]

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
    y.domain [params.yMin ? valueMin, params.yMax ? valueMax]

    _.each targets, (target) ->
      {values, drawNullAsZero} = target
      _.each values, (v) ->
        if v.value?
          v.y = y v.value
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

    xAxis.ticks(params.xAxisTicks)
    yAxis.ticks(params.yAxisTicks)

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

      g.selectAll('.target .crosshair-value')
        .data(targetValues)
        .attr('cx', (d) -> d.x)
        .attr('cy', (d) -> d.y)
        .style('visibility', (d) -> if d.value? then 'visible' else 'hidden')


    destroyFunctions.push mousePosition.onValue (p) ->
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
        extraWidth = 10
        c = ''
      else
        extraWidth = 0

      path = target.append("path")
        .attr('class', (d) -> d.lineMode)
        .attr('stroke', (d, i) -> d.color)
        .style('stroke-width', (d) -> d.lineWidth + extraWidth)
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
        extraRadius = 3
        opacity = 0
      else
        extraRadius = 0
        opacity = 1

      target.append('g').attr('class', 'circles')
        .each (d) ->
          circleColor = d.color
          radius = d.radius + extraRadius
          d3.select(this).selectAll('circle')
          .data((d) -> d.scatterValues)
          .enter().append("circle")
            .attr('cx', (d) -> d.x)
            .attr('cy', (d) -> y d.value)
            .attr('fill', circleColor)
            .attr('r', radius)
            .style('fill-opacity', opacity)

    addInfiniteLines = (target, hover) ->
      if hover
        extraWidth = 10
      else
        extraWidth = 0

      target.append('g').attr('class', 'infiniteLines')
        .each (d) ->
          lineColor = d.color
          lineWidth = d.lineWidth + extraWidth
          d3.select(this)
            .selectAll('line')
            .data((d) -> d.scatterValues)
            .enter().append('line').each (d) ->
              if d.value
                l = d3.select(@)
                  .attr('x1', d.x)
                  .attr('x2', d.x)
                  .attr('y1', 0)
                  .attr('y2', height)
                  .attr('stroke', lineColor)
                  .style('stroke-width', lineWidth)
                if hover
                  l
                    .style('stroke-opacity', 0)
                else
                  l
                    .style('stroke-opacity', lineOpacity)

    addTarget = (target, hover) ->
      target.each (d) ->
        sel = d3.select(@)
        {drawAsInfinite, type} = d
        if drawAsInfinite
          addInfiniteLines(sel, hover)
        else if type is 'line'
          addPath(sel, hover)
        else
          addCircles(sel, hover)

        unless hover
          if type == 'scatter'
            radius = d.radius + 3
          else
            radius = 4
          sel.append('circle').attr('class', 'crosshair-value')
            .style('visibility', 'hidden')
            .attr('fill', d.color)
            .attr('stroke', params.bgcolor)
            .attr('stroke-width', 2)
            .attr('r', radius)

    addTarget(target, false)
    addTarget(target, true)

    invisibility(legendG, params.hideLegend)
    legendFontSize = '11px'
    legendG.attr('transform', "translate(0,#{height + 30})")

    legendGTarget = legendG.selectAll('g').data(targets[...legendRowCount])
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
