colors = require './colors'
d3 = require 'd3'
_ = require 'underscore'
moment = require 'moment'
Bacon = require 'bacon.model'

clearExtent = (v) -> _.extend {}, v, {extent: null}
setBrushing = (v) -> _.extend {}, v, {brushing: true}
setNotBrushing = (v) -> _.extend {}, v, {brushing: false}

expandIsolatedValuesToLineSegments = (values) ->
  result = []
  segment_length = 0
  previous = null
  _.each values, (v, i) ->
    if v.value?
      segment_length++
      previous = v
    else
      if segment_length is 1
        result.push previous
      segment_length = 0

    result.push v

  if segment_length is 1
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

default_params =
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
  crosshairLineColor: '#ddd'
  crosshairTextColor: '#aaa'
  crosshairValueTextColor: '#aaa'
  brushColor: '#efefef'
  valueFormat: d3.format(',.4g')
  #lineWidth: 1

fgColorParams = ['axisLineColor', 'axisTextColor', 'crosshairLineColor', 'crosshairTextColor']

create = (container) ->
  x = d3.time.scale()
  y = d3.scale.linear()
  x_axis = d3.svg.axis().scale(x).orient('bottom')
  y_axis = d3.svg.axis().scale(y).orient('left')

  color = d3.scale.ordinal()

  mouse_over = new Bacon.Bus
  mouse_out = new Bacon.Bus
  clicks = new Bacon.Bus
  mouse_moves = new Bacon.Bus

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

  svg = d3.select(container).append('svg')
    .on('mousemove', (d, i) -> mouse_moves.push d3.mouse g.node())

  g = svg
    .append("g")

  xAxisG = g.append('g')
    .attr('class', 'x axis')

  yXaxisG = g.append('g')
    .attr('class', 'y axis')

  vertical_crosshair = g.append('line')
    .attr('class', 'crosshair')
    .attr('y1', 0)

  crosshair_time = g.append('text')
    .attr('class', 'crosshair-time')
    .attr('y', -6)

  brushG = g.append("g")
    .attr("class", "x brush")

  legend = d3.select(container).append('ul')
    .attr('class', 'legend')

  currentCrosshairTime = null
  allNames = []

  destroyFunctions = []
  destroy = ->
    _.each(destroyFunctions, (f) -> f())
    destroyFunctions = []

  draw = (data, params) ->
    destroy()
    if params?.fgcolor
      computedParams = _.object _.map fgColorParams, (k) -> [k, params.fgcolor]
    else
      computedParams = {}
    params = _.extend {}, default_params, computedParams, params
    width = params.width
    height = params.height

    cursorModel = params.cursor ? new Bacon.Model
    brushModel = params.brush ? new Bacon.Model brushing: false

    cursorBus = new Bacon.Bus
    brushBus = new Bacon.Bus

    destroyFunctions.push((-> cursorBus.end()), (-> brushBus.end()))

    externalCursorChanges = cursorModel.addSource cursorBus
    externalBrushChanges = brushModel.apply brushBus

    type = params.type

    margin = top: 20, right: 80, bottom: 30, left: 80

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

    observe_mouse = (s) ->
      s.on('mouseover', (d, i) -> mouse_over.push {index: i, event: d3.event, data: d})
      .on('mouseout', (d, i) -> mouse_out.push {index: i, event: d3.event, data: d})
      .on('click', (d, i) -> clicks.push i)

    selected = clicks.scan _.map(data, -> true), (state, i) ->
      new_state = _.clone state
      new_state[i] = !new_state[i]
      new_state
    selected.onValue (s) ->
      legend.selectAll('li')
      .data(s)
      .classed 'deselected', (d) -> !d
      g.selectAll('.target')
      .data(s)
      .classed 'deselected', (d) -> !d

    hover_selections = mouse_over.map ({index}) -> {index, selection: d3.select(container).selectAll ".target#{index}"}
    hover_selections.onValue ({selection, index}) ->
      if type == 'line'
        path = selection.select('path')
        path.style('stroke-width', (params.lineWidth ? 0) + 3)
      else
        circles = selection.select('.circles').selectAll('circle')
        circles.attr('r', 4)
      selection.classed 'hovered', true
    unhovers = hover_selections.merge(mouse_out)
      .withStateMachine([], (previous, event) -> [[event], previous])
      .filter (e) -> e.selection?
    unhovers.onValue ({selection, index}) ->
      selection.classed 'hovered', false
      if type == 'line'
        path = selection.select('path')
        path.style('stroke-width', params.lineWidth)
      else
        circles = selection.select('.circles').selectAll('circle')
        circles.attr('r', 2)

    mouse_position = mouse_moves.map (pos) ->
      x_constrained = Math.max 0, Math.min(pos[0], width)
      time: x.invert x_constrained
      value: y.invert pos[1]
      x: x_constrained
      y: pos[1]

    time_min = null
    time_max = null
    _.each data, ({datapoints}, j) ->
      if datapoints.length > 0
        _.each [0, datapoints.length - 1], (i) ->
          datapoint = datapoints[i]
          value = get_value datapoint, i, j
          timestamp = get_timestamp datapoint, i, j
          time_min = Math.min timestamp, time_min ? timestamp
          time_max = Math.max timestamp, time_max

    time_min = new Date(time_min * 1000)
    time_max = new Date(time_max * 1000)
    x.domain [params.xMin ? time_min, params.xMax ? time_max]

    stack.offset(params.areaOffset)

    if type is 'line'
      area_opacity = params.areaAlpha
      line_opacity = 1.0

      if params.interpolate?
        line.interpolate params.interpolate
        area.interpolate params.interpolate

    if params.simplify
      simplify = _.partial simplifyPoints, params.simplify
    else
      simplify = _.identity

    if params.drawNullAsZero
      transform_value = (v) -> v ? 0
      filter_scatter_values = simplify
      expand_line_values = simplify
    else
      # TODO this won't work well with stack
      transform_value = (v) -> v
      filter_scatter_values = (values) ->
        simplify _.filter values, (d) -> d.value?
      expand_line_values = _.compose expandIsolatedValuesToLineSegments, simplify

    value_min = null
    value_max = null
    targets = for s, targetIndex in data
      values = for datapoint, i in s.datapoints
        value = get_value datapoint, i, targetIndex
        timestamp = get_timestamp datapoint, i, targetIndex
        time = new Date(timestamp * 1000)
        value = transform_value value
        value_min = Math.min value, value_min ? value if value?
        value_max = Math.max value, value_max
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
      value_min = null
      value_max = null
      for {values} in targets
        for {value, y0} in values
          value += y0
          value_min = Math.min value, value_min
          value_max = Math.max value, value_max

    if value_min == value_max
      value_min = Math.round(value_min) - 1
      value_max = Math.round(value_max) + 1
    y.domain [params.yMin ? value_min, params.yMax ? value_max]

    _.each targets, (target) ->
      {values} = target
      _.each values, (v) ->
        if v.value?
          v.y = y v.value
      target.lineValues = expand_line_values values
      target.scatterValues = filter_scatter_values values

    svg
      .attr('width', width + margin.left + margin.right)
      .attr('height', height + margin.top + margin.bottom)
      .style('background-color', params.bgcolor)

    g
      .attr("transform", "translate(#{margin.left},#{margin.top})")

    xAxisG
      .attr('class', 'x axis')
      .attr('transform', "translate(0, #{height})")
      .call(x_axis)

    yXaxisG.call(y_axis)

    g.selectAll('.axis path, .axis line').attr('stroke', params.axisLineColor)
    g.selectAll('.axis text').attr('fill', params.axisTextColor)

    vertical_crosshair
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
      vertical_crosshair
        .attr('x1', x)
        .attr('x2', x)

      crosshair_time
        .text(moment(time).format('lll'))
        .attr('x', x)
        .attr('fill', params.crosshairTextColor)

      target_values = _.map targets, (t) ->
        i = t.bisector.left t.values, time, 1
        d0 = t.values[i - 1]
        d1 = t.values[i]
        if d0 and d1
          if time - d0.time > d1.time - time then d1 else d0
        else if d0
          d0

      legend.selectAll('.crosshair-value')
        .data(target_values)
        .text((d) -> params.valueFormat(d?.value))
        .style(color: params.crosshairValueTextColor)

    mouse_position.onValue (p) ->
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
      .call(observe_mouse)
    target.exit().remove()
    target.selectAll('g > *').remove()


    add_path = (target, hover) ->
      if hover
        lineWidth = (params.lineWidth ? 0) + 10
      else
        lineWidth = params.lineWidth

      path = target.append("path")
        .attr('class', (d) -> d.lineMode)
        .attr('stroke', (d, i) -> d.color)
        .style('stroke-width', lineWidth)
        .attr('fill', (d, i) -> if d.lineMode is 'area' then d.color)
        .attr('d', (d, i) -> d.lineFn(d.lineValues))
      if hover
        path
          .style('stroke-opacity', 0)
          .style('fill-opacity', 0)
      else
        path
          .style('stroke-opacity', line_opacity)
          .style('fill-opacity', area_opacity)

    add_circles = (target, hover) ->
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
      add_path target, false
      add_path target, true
    else if type is 'scatter'
      add_circles target, false
      add_circles target, true

    legend_target = legend.selectAll('li')
      .data(targets)

    legendTargetEnter = legend_target.enter().append('li')
      .attr('class', (d, i) -> "target#{i}")
      .attr('data-target', (d) -> d.name)
      .call(observe_mouse)

    legendTargetEnter.append('span')
      .attr('class', 'color')
    legendTargetEnter.append('span')
      .attr('class', 'name')
    legendTargetEnter.append('span')
      .attr('class', 'crosshair-value')

    legend_target.select('span.color')
      .style('color', (d, i) -> d.color)

    legend_target.select('span.name')
      .text((d) -> d.name)

    legend_target.exit().remove()

  {draw, destroy}

module.exports = {create}
