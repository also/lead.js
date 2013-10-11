define (require) ->
  colors = require 'colors'
  d3 = require 'd3'
  moment = require 'moment'
  Q = require 'q'
  Bacon = require 'baconjs'
  modules = require 'modules'

  graph = modules.create 'graph', ({fn, cmd, settings}) ->
    fn 'graph', 'Graphs time series data using d3', (data, params={}) ->
      @nested 'graph', ->
        $result = @div()
        data = Bacon.fromPromise data if Q.isPromise data
        stream = Bacon.combineTemplate {data, params}
        stream.onValue ({data, params}) =>
          $result.empty()
          graph.draw $result.get(0), data, params
        # TODO seems like the combined stream doesn't error?
        stream.onError (error) =>
          @error error

    draw_pie: (container, data, params) ->
      width = params.width or 800
      height = params.height or 400
      radius = Math.min(width, height) / 2

      margin = top: 20, right: 80, bottom: 30, left: 80
      color = d3.scale.ordinal().range params.d3_colors ? colors.d3.category10

      get_value = params.get_value ? (d) -> d

      arc = d3.svg.arc()
        .outerRadius(radius - 10)
        .innerRadius(0)

      pie = d3.layout.pie().sort(null)

      svg = d3.select(container).append('svg')
          .attr('width', width + margin.left + margin.right)
          .attr('height', height + margin.top + margin.bottom)
        .append('g')
          .attr('transform', "translate(#{width / 2},#{height / 2})")

      g = svg.selectAll('.arc')
          .data(pie(data))
        .enter().append('g')
          .attr('class', 'arc')

      g.append("path")
          .attr("d", arc)
          .style("fill", (d, i) -> color i)

    draw: (container, data, params) ->
      width = params.width or 800
      height = params.height or 400

      type = params.type or 'line'

      margin = top: 20, right: 80, bottom: 30, left: 80

      width -= margin.left + margin.right
      height -= margin.top + margin.bottom

      x = d3.time.scale().range([0, width])
      y = d3.scale.linear().range([height, 0])

      get_value = params.get_value or ([value, timestamp]) -> value
      get_timestamp = params.get_timestamp or ([value, timestamp]) -> timestamp

      x_axis = d3.svg.axis().scale(x).orient('bottom')
      y_axis = d3.svg.axis().scale(y).orient('left')

      color = d3.scale.ordinal().range params.d3_colors ? colors.d3.category10

      mouse_over = new Bacon.Bus
      mouse_out = new Bacon.Bus
      clicks = new Bacon.Bus
      observe_mouse = (s) ->
        s.on('mouseover', (d, i) -> mouse_over.push i)
         .on('mouseout', (d, i) -> mouse_out.push i)
         .on('click', (d, i) -> clicks.push i)

      selected = clicks.scan _.map(data, -> true), (state, i) ->
        new_state = _.clone state
        new_state[i] = !new_state[i]
        new_state
      selected.onValue (s) ->
        # TODO
        if g?
          legend.selectAll('li')
            .data(s)
            .classed 'deselected', (d) -> !d
          g.selectAll('.target')
            .data(s)
            .classed 'deselected', (d) -> !d

      hover_selections = mouse_over.map (i) -> d3.select(container).selectAll ".target#{i}"
      hover_selections.onValue '.classed', 'hovered', true
      unhovers = hover_selections.merge(mouse_out)
        .withStateMachine([], (previous, event) -> [[event], previous])
        .filter _.identity
      unhovers.onValue '.classed', 'hovered', false

      if type is 'line'
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

        if params.interpolate?
          line.interpolate params.interpolate
          area.interpolate params.interpolate

        line_mode = (d, i) ->
          if params.areaMode is 'all' or params.areaMode is 'stacked'
            'area'
          else if params.areaMode is 'first' and i is 0
            'area'
          else
            'line'

        stack = d3.layout.stack()
          .offset(params.areaOffset ? 'zero')
          .values((d) -> d.values)
          .x((d) -> d.time)
          .y((d) -> d.value)
          .out((d, y0, y) ->
            d.y0 = y0
            d.value = y)

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
        values = for datapoint in s.datapoints
          value = get_value datapoint
          timestamp = get_timestamp datapoint
          time_min = Math.min timestamp, time_min ? timestamp
          time_max = Math.max timestamp, time_max
          value = transform_value value
          value_min = Math.min value, value_min ? value if value?
          value_max = Math.max value, value_max
          {value, time: moment(timestamp * 1000), original: datapoint}
        {values, name: s.target}

      if params.areaMode is 'stacked'
        stack targets
        value_min = null
        value_max = null
        for {values} in targets
          for {value, y0} in values
            value += y0
            value_min = Math.min value, value_min
            value_max = Math.max value, value_max

      time_min = moment(time_min * 1000)
      time_max = moment(time_max * 1000)
      x.domain [time_min.toDate(), time_max.toDate()]
      if value_min == value_max
        value_min = Math.round(value_min) - 1
        value_max = Math.round(value_max) + 1
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
          .attr('class', (d, i) -> "target target#{i}")

      if type is 'line'
        target.append("path")
            .attr('class', line_mode)
            .attr('stroke', (d, i) -> color i)
            .style('stroke-width', (d, i) -> params.lineWidth)
            .style('stroke-opacity', line_opacity)
            .attr('fill', (d, i) -> if line_mode(d, i) is 'area' then color i)
            .style('fill-opacity', area_opacity)
            .attr('d', (d, i) -> line_fn(d, i)(d.values))
            .call(observe_mouse)
      else if type is 'scatter'
        target.selectAll('circle')
            .data((d) -> d.values)
          .enter().append("circle")
            .attr('cx', (d) -> x d.time)
            .attr('cy', (d) -> y d.value)
            .attr('fill', (d, i, j) -> color j)
            .attr('r', 2)

      legend = d3.select(container).append('ul')
          .attr('class', 'legend')
      legend_target = legend.selectAll('li')
          .data(targets)
        .enter().append('li')
          .attr('class', (d, i) -> "target#{i}")
          .attr('data-target', (d) -> d.name)
          .call(observe_mouse)
      legend_target.append('span')
          .style('color', (d, i) -> color i)
          .attr('class', 'color')
      legend_target.append('span')
          .text((d) -> d.name)

      if params.bgcolor?
        svg.style 'background-color', params.bgcolor

