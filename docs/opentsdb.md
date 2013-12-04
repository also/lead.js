# OpenTSDB

```coffeescript
{start, end, aggregation, group, time_series}
```

**`start`**:

**`end`**: see [OpenTSDB Dates and Times](http://opentsdb.net/docs/build/html/user_guide/query/dates.html).

**`time_series`**: a array of string (see [OpenTSDB Metric Query String Format](http://opentsdb.net/docs/build/html/api_http/query/index.html#metric-query-string-format)), or

```coffeescript
{metric_name, aggregation, downsample, tags, rate}
```

**`aggregation`**: the name of an aggregation function to use. See [OpenTSDB Available Aggregators](http://opentsdb.net/docs/build/html/user_guide/query/aggregators.html#available-aggregators).

**`downsample`**:

```coffeescript
{period, aggregation}
```
