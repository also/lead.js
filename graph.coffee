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

    line = d3.svg.line()
      .x((d) -> x d.time)
      .y((d) -> y d.value)
      .defined((d) -> d.value?)

    time_min = null
    time_max = null
    value_min = null
    value_max = null
    targets = for s in data
      values = for [value, timestamp] in s.datapoints
        time_min = Math.min timestamp, time_min ? timestamp
        time_max = Math.max timestamp, time_max
        value_min = Math.min value, value_min ? value if value?
        value_max = Math.max value, value_max
        {value, time: moment(timestamp * 1000)}
      {values, name: s.target}

    time_min = moment(time_min * 1000)
    time_max = moment(time_max * 1000)
    x.domain [time_min.toDate(), time_max.toDate()]
    y.domain [value_min, value_max]

    svg = d3.select(container).append('svg')
        .attr('width', width + margin.left + margin.right)
        .attr('height', height + margin.top + margin.bottom)
      .append("g")
        .attr("transform", "translate(#{margin.left},#{margin.top})")

    svg.append('g')
      .attr('class', 'x axis')
      .attr('transform', "translate(0, #{height})")
      .call(x_axis)

    svg.append('g')
      .attr('class', 'y axis')
      .call(y_axis)

    target = svg.selectAll('.target')
        .data(targets)
      .enter().append("g")
        .attr('class', 'target')

    target.append("path")
        .attr('class', 'line')
        .attr('stroke', (d, i) -> color i)
        .attr('d', (d) -> line(d.values))

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
