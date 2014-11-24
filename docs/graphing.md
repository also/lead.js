# Graphing

lead.js provides the `graph` function to draw time-series graphs.

It can be called in a few different ways. The simplest way is with a promise of time-series data and graph options:

```coffeescript
graph promise, options
```

To graph [OpenTSDB](opentsdb.md) data, use this form. The `tsd` function returns a promise.

For Graphite data, there's a convenience form that calls `graphite.get_data` on it's arguments:

```coffeescript
graph {target, options}
graph {targets, options}
graph {target, yMin, yMax...}
graph {targets, yMin, yMax...}
graph targets, options
graph target, target, target, ..., options
```

Using these forms is the same as calling

```coffeescript
graph graphite.get_data({targets, options}), options
```

To see how the arguments are interpreted, use the `graphite.params` function:

```coffeescript
graphite.params 'a', 'b', keepLastValue('c'), yMax: 0
```

```json
{
  "yMax": 0,
  "target": [
    "a",
    "b",
    "keepLastValue('c')"
  ]
}
```

## Graph Options

The `graph` function supports several options. Most of the option names and values are taken from Graphite.

`type`: `'scatter'` or `'line'`. Default: `'line'`.

`areaMode`: `'all'`, `'stacked'` or `'first'`. Defaul: unset.

`areaOffset`: see https://github.com/mbostock/d3/wiki/Stack-Layout#wiki-offset. Default: `zero`.

`drawNullAsZero`: `true` or `false`. Default: `false`.

`width`, `height`

`bgcolor`

`lineWidth`

`yMin`, `yMax`

`d3_colors`: Default: `colors.d3.category10`

`getValue`: Function `(datapoint) -> value`.

`getTimestamp`: Function `(datapoint) -> timestamp`.

`interpolate`: See https://github.com/mbostock/d3/wiki/SVG-Shapes#wiki-line_interpolate or https://github.com/mbostock/d3/wiki/SVG-Shapes#wiki-area_interpolate.
