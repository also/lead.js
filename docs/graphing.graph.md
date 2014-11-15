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
    "datapoints": [[value, timestamp], [value, timestamp], ...]
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

# Options

## [`areaMode`](help:server.parameters.areaMode)

```
now = moment().unix()
data = [
  {target: 'target 1', datapoints: [[now, 1], [now + 60, 2], [now + 120, 3]]}
  {target: 'target 2', datapoints: [[now, 0], [now + 60, 3], [now + 120, 1]]}
]

options width: 400, height: 200
graph data, areaMode: 'none'
graph data, areaMode: 'first'
graph data, areaMode: 'all'
graph data, areaMode: 'stacked'
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

## `type`

The type of graph to generate. `"line"` (the default) and `"scatter"` are supported.

```
now = moment().unix()
data = [
  {target: 'target 1', datapoints: [[now, 1], [now + 60, 2], [now + 120, 3]]}
  {target: 'target 2', datapoints: [[now, 0], [now + 60, 3], [now + 120, 1]]}
]

options width: 400, height: 200
graph data, type: 'line'
graph data, type: 'scatter'
```

## `lineWidth`

```
now = moment().unix()
data = [
  {target: 'target 1', datapoints: [[now, 1], [now + 60, 2], [now + 120, 3]]}
  {target: 'target 2', datapoints: [[now, 0], [now + 60, 3], [now + 120, 1]]}
]

options width: 400, height: 200
graph data, lineWidth: 0.3
graph data, lineWidth: 3
graph data, lineWidth: 30
```

## `areaOffset`

Used in conjuction with `areaMode`, `areaOffset` controls the baseline of the plot.
This is used as the argument to the d3 [`offset` function](https://github.com/mbostock/d3/wiki/Stack-Layout#wiki-offset)
and can be used to create "streamgraphs" or graphs that are normalized to fill the plot area.

```
now = moment().unix()
data = [
  {target: 'target 1', datapoints: [[now, 1], [now + 60, 2], [now + 120, 3]]}
  {target: 'target 2', datapoints: [[now, 0], [now + 60, 3], [now + 120, 1]]}
]

options width: 400, height: 200
graph data, areaMode: 'stacked', areaOffset: 'wiggle'
graph data, areaMode: 'stacked', areaOffset: 'silhouette'
graph data, areaMode: 'stacked', areaOffset: 'expand'
```

## `interpolate`

See https://github.com/mbostock/d3/wiki/SVG-Shapes#wiki-line_interpolate or https://github.com/mbostock/d3/wiki/SVG-Shapes#wiki-area_interpolate.

```
now = moment().unix()
data = [
  {target: 'target 1', datapoints: [[now, 1], [now + 60, 2], [now + 120, 3]]}
  {target: 'target 2', datapoints: [[now, 0], [now + 60, 3], [now + 120, 1]]}
]

options width: 400, height: 200
graph data, interpolate: 'basis'
graph data, interpolate: 'cardinal'
graph data, interpolate: 'basis'
graph data, interpolate: 'step-before'
graph data, interpolate: (points) -> points.join 'A 1,1 0 0 1 '
md 'see http://bl.ocks.org/mbostock/3310323'
```

## `drawNullAsZero`

```
now = moment().unix()
data = [
  {target: 'target 1', datapoints: [[now, 1], [now + 60, 2], [now + 120, null], [now + 180, 4]]}
  {target: 'target 2', datapoints: [[now, 0], [now + 60, 3], [now + 120, 1], [now + 180, 2]]}
]

options width: 400, height: 200
graph data, drawNullAsZero: true
graph data, drawNullAsZero: false
```

## `d3_colors`

An array of colors. The options from https://github.com/mbostock/d3/wiki/Ordinal-Scales#wiki-categorical-colors
and https://github.com/mbostock/d3/blob/master/lib/colorbrewer/colorbrewer.js
are available in the `colors` module as, e.g., `d3.category20c` or `brewer.Purples[9]`.

The default is `d3.category10`.

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

## `get_value` and `get_timestamp`

```
now = moment().unix()
data = [
  {target: 'target 1', datapoints: [1, 2, 3]}
  {target: 'target 2', datapoints: [0, 3, 1]}
]

options width: 400, height: 200
graph data,
  get_value: (v, i) -> v
  get_timestamp: (v, i) -> now + i * 60
```
