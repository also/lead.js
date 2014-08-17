`graph` accepts a [Graphite target](help:graphite_functions) or promise of graph data.

Graphite targets are converted to a promise using [`graphite.get_data`](help:graphite.get_data).

For example:

<!-- norun -->
```
graph randomWalkFunction 'hello, world'
```

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
Q = require 'q'
now = moment().unix()
data = Q [
  {target: 'target 1', datapoints: [[1, now], [2, now + 60], [3, now + 120]]}
  {target: 'target 2', datapoints: [[0, now], [3, now + 60], [1, now + 120]]}
]

graph data
```

# Options

## [`areaMode`](help:graphite_parameters.areaMode)

```
Q = require 'q'
now = moment().unix()
data = Q [
  {target: 'target 1', datapoints: [[1, now], [2, now + 60], [3, now + 120]]}
  {target: 'target 2', datapoints: [[0, now], [3, now + 60], [1, now + 120]]}
]

options width: 400, height: 200
graph data, areaMode: 'none'
graph data, areaMode: 'first'
graph data, areaMode: 'all'
graph data, areaMode: 'stacked'
```

## `width` and `height`
Set the width and height of the plot area. The legend is outside this area.

## `type`

The type of graph to generate. `"line"` (the default) and `"scatter"` are supported.

```
Q = require 'q'
now = moment().unix()
data = Q [
  {target: 'target 1', datapoints: [[1, now], [2, now + 60], [3, now + 120]]}
  {target: 'target 2', datapoints: [[0, now], [3, now + 60], [1, now + 120]]}
]

options width: 400, height: 200
graph data, type: 'line'
graph data, type: 'scatter'
```

## `lineWidth`

```
Q = require 'q'
now = moment().unix()
data = Q [
  {target: 'target 1', datapoints: [[1, now], [2, now + 60], [3, now + 120]]}
  {target: 'target 2', datapoints: [[0, now], [3, now + 60], [1, now + 120]]}
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
Q = require 'q'
now = moment().unix()
data = Q [
  {target: 'target 1', datapoints: [[1, now], [2, now + 60], [3, now + 120]]}
  {target: 'target 2', datapoints: [[0, now], [3, now + 60], [1, now + 120]]}
]

options width: 400, height: 200
graph data, areaMode: 'stacked', areaOffset: 'wiggle'
graph data, areaMode: 'stacked', areaOffset: 'silhouette'
graph data, areaMode: 'stacked', areaOffset: 'expand'
```

## `interpolate`

```
Q = require 'q'
now = moment().unix()
data = Q [
  {target: 'target 1', datapoints: [[1, now], [2, now + 60], [3, now + 120]]}
  {target: 'target 2', datapoints: [[0, now], [3, now + 60], [1, now + 120]]}
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
Q = require 'q'
now = moment().unix()
data = Q [
  {target: 'target 1', datapoints: [[1, now], [2, now + 60], [null, now + 120], [4, now + 180]]}
  {target: 'target 2', datapoints: [[0, now], [3, now + 60], [1, now + 120], [2, now + 180]]}
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
Q = require 'q'
Colors = require 'colors'
now = moment().unix()

targets = (n) ->
  Q(for i in [1..n]
    target: "target #{i}", datapoints: [i + j, now + j * 60] for j in [0...3]
  )

options width: 400, height: 200, lineWidth: 2
graph targets(10)
graph targets(10), d3_colors: Colors.brewer.Spectral[10]
graph targets(3), d3_colors: ['#333', '#777', '#bbb']
graph targets(3), d3_colors: Colors.brewer.Set1[3]
graph targets(9), d3_colors: Colors.brewer.Set1[3]
```

## `yMin` and `yMax`

## `bgcolor`

## `get_value` and `get_timestamp`

```
Q = require 'q'
now = moment().unix()
data = Q [
  {target: 'target 1', datapoints: [1, 2, 3]}
  {target: 'target 2', datapoints: [0, 3, 1]}
]

options width: 400, height: 200
graph data,
  get_value: (v, i) -> v
  get_timestamp: (v, i) -> now + i * 60
```
