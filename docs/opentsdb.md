# OpenTSDB

<!-- norun -->
```coffeescript
{start, end, aggregation, group, time_series}
```

**`start`**:

**`end`**: see [OpenTSDB Dates and Times](http://opentsdb.net/docs/build/html/user_guide/query/dates.html).

**`time_series`**: an array of strings (see [OpenTSDB Metric Query String Format](http://opentsdb.net/docs/build/html/api_http/query/index.html#metric-query-string-format)), or

<!-- norun -->
```coffeescript
{metric_name, aggregation, downsample, tags, rate}
```

**`aggregation`**: the name of an aggregation function to use. See [OpenTSDB Available Aggregators](http://opentsdb.net/docs/build/html/user_guide/query/aggregators.html#available-aggregators).

**`downsample`**:

<!-- norun -->
```coffeescript
{period, aggregation}
```

## Examples

<!-- norun -->
```coffeescript
graph tsd
  start: '2d-ago'
  end: '1d-ago'
  time_series: [
    'sys.cpu.user',
    {
      metric_name: 'sys.cpu.user', 
      tags: {host: 'webserver01'}
      downsample: {period: '10m', aggregation: 'max'}
    }
  ]
```
