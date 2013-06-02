lead.graph =
  draw: (container, data, params) ->
    width = params.width or 800
    height = params.height or 400

    margin = top: 20, right: 80, bottom: 30, left: 80

    width -= margin.left + margin.right
    height -= margin.top + margin.bottom

    x = d3.time.scale().range([0, width])
    y = d3.scale.linear().range([height, 0])
    x_axis = d3.svg.axis().scale(x).orient('bottom')
    y_axis = d3.svg.axis().scale(y).orient('left')
    color = d3.scale.category10()

    area_opacity = params.areaAlpha ? 1.0
    line_opacity = 1.0

    area = d3.svg.area()
      .x((d) -> x d.time)
      .y0((d) -> y d.y0 ? 0)
      .y1((d) -> y d.value + (d.y0 ? 0))
      .defined((d) -> d.value?)

    line = d3.svg.line()
      .x((d) -> x d.time)
      .y((d) -> y d.value)
      .defined((d) -> d.value?)

    line_mode = (d, i) ->
      if params.areaMode is 'all' or params.areaMode is 'stacked'
        'area'
      else if params.areaMode is 'first' and i is 0
        'area'
      else
        'line'

    stack = d3.layout.stack()
      .values((d) -> d.values)
      .x((d) -> d.time)
      .y((d) -> d.value)
      .out((d, y0) -> d.y0 = y0)

    line_fn = (d, i) ->
      mode = line_mode d, i
      if mode is 'line'
        line
      else
        area

    transform_value =
      if params.drawNullAsZero
        (v) -> v ? 0
      else
        (v) -> v

    time_min = null
    time_max = null
    value_min = null
    value_max = null
    targets = for s in data
      values = for [value, timestamp] in s.datapoints
        time_min = Math.min timestamp, time_min ? timestamp
        time_max = Math.max timestamp, time_max
        value = transform_value value
        value_min = Math.min value, value_min ? value if value?
        value_max = Math.max value, value_max
        {value, time: moment(timestamp * 1000)}
      {values, name: s.target}

    if params.areaMode is 'stacked'
      stack targets
      for {values} in targets
        for {value, y0} in values
          value += y0
          value_min = Math.min value, value_min
          value_max = Math.max value, value_max

    time_min = moment(time_min * 1000)
    time_max = moment(time_max * 1000)
    x.domain [time_min.toDate(), time_max.toDate()]
    y.domain [params.yMin ? value_min, params.yMax ? value_max]

    svg = d3.select(container).append('svg')
        .attr('width', width + margin.left + margin.right)
        .attr('height', height + margin.top + margin.bottom)
    g = svg
      .append("g")
        .attr("transform", "translate(#{margin.left},#{margin.top})")

    g.append('g')
      .attr('class', 'x axis')
      .attr('transform', "translate(0, #{height})")
      .call(x_axis)

    g.append('g')
      .attr('class', 'y axis')
      .call(y_axis)

    target = g.selectAll('.target')
        .data(targets)
      .enter().append("g")
        .attr('class', 'target')

    target.append("path")
        .attr('class', line_mode)
        .attr('stroke', (d, i) -> color i)
        .style('stroke-width', (d, i) -> params.lineWidth)
        .style('stroke-opacity', line_opacity)
        .attr('fill', (d, i) -> if line_mode(d, i) is 'area' then color i)
        .style('fill-opacity', area_opacity)
        .attr('d', (d, i) -> line_fn(d, i)(d.values))

    legend = d3.select(container).append('ul')
        .attr('class', 'legend')
    legend_target = legend.selectAll('li')
        .data(targets)
      .enter().append('li')
        .attr('data-graphite-target', (d) -> d.name)
    legend_target.append('span')
        .style('color', (d, i) -> color i)
        .attr('class', 'color')
    legend_target.append('span')
        .text((d) -> d.name)
  
    if params.bgcolor?
      svg.style 'background-color', params.bgcolor

