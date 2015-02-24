`graph` accepts a [DSL expression](help:server.functions), time-series data, or a promise or observable that produces time-series data.

# Usage

## `graph(dslExpression..., options)`

DSL expressions are converted to a promise using [`server.get_data`](help:server.get_data).

For example:

<!-- norun -->
```
graph randomWalkFunction 'hello, world'
```

## `graph(data, options)`

Graphs `data` immediately.

## `graph(leadDataSource, options)`

Graphs the result of `leadDataSource` when it is fulfilled.

## `graph(promise, options)`

Graphs the result of `promise` when it is fulfilled.

## `graph(dataObservable, options)`

Graphs every new value of `dataObservable`.

# Data format
The format for graph data is an array of time series:

<!-- norun -->
```
[
  {
    "target": "target name",
    "datapoints": [[value, timestamp], [value, timestamp], ...],
    "options": {"color": "#ff0000"}
  }, ...
]
```

For example:

```
now = moment().unix()
data = [
  {target: 'target 1', datapoints: [[now, 1], [now + 60, 2], [now + 120, 3]]}
  {target: 'target 2', datapoints: [[now, 0], [now + 60, 3], [now + 120, 1]]}
]

graph data
```

<!-- code-prefix -->
```
now = moment().unix()
data = [
  {target: 'target 1', datapoints: [[now, 1], [now + 60, 2], [now + 120, 3]]}
  {target: 'target 2', datapoints: [[now, 0], [now + 60, 3], [now + 120, 1]]}
]
options width: 400, height: 200
```

# Options

## `title`

Sets the title displayed at the top of the graph.

## [`areaMode`](help:server.parameters.areaMode)

```
graph data, areaMode: 'none', title: 'none'
graph data, areaMode: 'first', title: 'first'
graph data, areaMode: 'all', title: 'all'
graph data, areaMode: 'stacked', title: 'stacked'
```

## `bindToBrush`

When called with a DSL expression or `LeadDataSource`, the data will be reloaded with the `start` and `end` options supplied by the bound brush.

If the value is `true`, the value of the `brush` option will be used. Otherwise, a specific brush instance can be used by multiple graphs by passing the instance.

If `brush` is not set, this brush will be displayed.

## `brush`

The brush to display on the graph. A single brush instance can be shared across multiple graphs. See [`shareBrush`](help:graphing.shareBrush)

## `cursor`

The cursor to display on the graph. A single cursor instance can be shared across multiple graphs. See [`shareCursor`](help:graphing.shareCursor)

## `width` and `height`
Set the width and height of the plot area. The legend is outside this area.

## `fixedHeight`

If set to `false` (the default), the graph will expand to fit the height of the legend. If set to `true`, the graph area will shrink to fit the legend.

```
grid 2, ->
  graph data, fixedHeight: false, title: 'fixedHeight: false'
  graph data, fixedHeight: true, title: 'fixedHeight: true'
```

## `legendMaxHeight`

## `xAxisTicks`

## `yAxisTicks`

## `type`

The type of graph to generate. `"line"` (the default) and `"scatter"` are supported.

```
graph data, type: 'line', title: 'line'
graph data, type: 'scatter', 'title': 'scatter'
```

## `lineWidth`

```
graph data, lineWidth: 0.3, title: '0.3'
graph data, lineWidth: 3, title: '3'
graph data, lineWidth: 30, title: '30'
```

## `radius`

```
options type: 'scatter'
graph data, radius: 1, title: '1'
graph data, radius: 3, title: '3'
graph data, radius: 30, title: '30'
```

## `drawAsInfinite`

```
options drawAsInfinite: true
graph data, radius: 1, title: 'drawAsInfinite'
```

See the [`drawAsInfinite`](help:server.functions.drawAsInfinite) server function.

## `areaOffset`

Used in conjuction with `areaMode`, `areaOffset` controls the baseline of the plot.
This is used as the argument to the d3 [`offset` function](https://github.com/mbostock/d3/wiki/Stack-Layout#wiki-offset)
and can be used to create "streamgraphs" or graphs that are normalized to fill the plot area.

```
graph data, areaMode: 'stacked', areaOffset: 'wiggle', title: 'wiggle'
graph data, areaMode: 'stacked', areaOffset: 'silhouette', title: 'silhouette'
graph data, areaMode: 'stacked', areaOffset: 'expand', title: 'expand'
```

## `interpolate`

See https://github.com/mbostock/d3/wiki/SVG-Shapes#wiki-line_interpolate or https://github.com/mbostock/d3/wiki/SVG-Shapes#wiki-area_interpolate.

```
graph data, interpolate: 'basis', title: 'basis'
graph data, interpolate: 'cardinal', title: 'cardinal'
graph data, interpolate: 'step-before', title: 'step-before'
graph data, title: 'arcs', interpolate: (points) -> points.join 'A 1,1 0 0 1 ',
md 'see http://bl.ocks.org/mbostock/3310323'
```

## `drawNullAsZero`

<!-- skip-code-prefix -->
```
now = moment().unix()
data = [
  {target: 'target 1', datapoints: [[now, 1], [now + 60, 2], [now + 120, null], [now + 180, 4]]}
  {target: 'target 2', datapoints: [[now, 0], [now + 60, 3], [now + 120, 1], [now + 180, 2]]}
]

options width: 400, height: 200
graph data, drawNullAsZero: true, title: 'true'
graph data, drawNullAsZero: false, title: 'false'
```

## `d3_colors`

An array of colors. The options from https://github.com/mbostock/d3/wiki/Ordinal-Scales#wiki-categorical-colors
and https://github.com/mbostock/d3/blob/master/lib/colorbrewer/colorbrewer.js
are available in the `colors` module as, e.g., `d3.category20c` or `brewer.Purples[9]`.

The default is `d3.category10`.

<!-- skip-code-prefix -->
```
Colors = require 'colors'
now = moment().unix()

targets =
  for i in [1..10]
    target: "target #{i}", datapoints: [now + j * 60, i + j] for j in [0...3]

options width: 400, height: 200, lineWidth: 2
graph targets
graph targets, d3_colors: Colors.brewer.Spectral[10]
graph targets[...3], d3_colors: ['#333', '#777', '#bbb']
graph targets[...3], d3_colors: Colors.brewer.Set1[3]
graph targets[...9], d3_colors: Colors.brewer.Set1[3]
```

## `yMin` and `yMax`

## `bgcolor`

The background color of the graph.

```
graph data, title: 'bgcolor', bgcolor: '#eee'
```

## `fgcolor`

Sets the color of all foreground elements.

```
graph data, title: 'fgcolor', fgcolor: '#00ebba'
```

The color of individual foreground elements can be set using `axisLineColor`, `axisTextColor`, `crosshairLineColor`, `crosshairTextColor`, `crosshairValueTextColor`, `brushColor`, `titleTextColor`, or `legendTextColor`.

## `getValue` and `getTimestamp`

Functions called on each entry in `datapoints` to get the value and timestamp. Both functions take the arguments `datapoint, index`. The default functions assume each data point is an array of `[timestamp, value]`.

<!-- skip-code-prefix -->
```
now = moment().unix()
data = [
  {target: 'target 1', datapoints: [1, 2, 3]}
  {target: 'target 2', datapoints: [0, 3, 1]}
]

options width: 400, height: 200
graph data,
  getValue: (v, i) -> v
  getTimestamp: (v, i) -> now + i * 60
```

## `hideAxes`, `hideXAxis`, and `hideYAxis`

```
graph data, title: 'hideAxes', hideAxes: true
graph data, title: 'hideXAxis', hideXAxis: true
graph data, title: 'hideYAxis', hideYAxis: true
```

## `hideLegend`

```
graph data, title: 'hideLegend', hideLegend: true
```

## `areaAlpha`, `pointAlpha`, `lineAlpha`, and `alpha`

## `refreshInterval`

The interval, in seconds, between loads of the graph data. When unset (the default), the data will not be reloaded. This only applies to calls to `graph` where the data can be reloaded.
