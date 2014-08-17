_ = require 'underscore'
$ = require 'jquery'
Bacon = require 'bacon.model'
Q = require 'q'
URI = require 'URIjs'
moment = require 'moment'
React = require './react_abuse'
dsl = require './dsl'
modules = require './modules'
function_names = require './functions'
http = require './http'
docs = require './graphite_docs'
parser = require './graphite_parser'
Builtins = require './builtins'
Html = require './html'
Documentation = require './documentation'
Context = require './context'
Components = require './components'

graphite = modules.create 'graphite', ({fn, component_fn, cmd, component_cmd, settings, doc}) ->
  build_function_doc = (ctx, doc) ->
    FunctionDocsComponent {ctx, docs: docs.function_docs[doc.function_name]}

  build_parameter_doc = (ctx, doc) ->
    ParameterDocsComponent {ctx, docs: docs.parameter_docs[doc.parameter_name]}

  _.each docs.function_docs, (d, n) ->
    Documentation.register_documentation ['graphite_functions', n], function_name: n, summary: d.signature, complete: build_function_doc

  _.each docs.parameter_docs, (d, n) ->
    Documentation.register_documentation ['graphite_parameters', n], parameter_name: n, summary: 'A Graphite parameter', complete: build_parameter_doc

  Documentation.register_documentation 'graphite_functions', index: true
  Documentation.register_documentation 'graphite_parameters', index: true

  args_to_params = (context, args) ->
    graphite.args_to_params {args, default_options: context.options()}

  default_target_command = 'graph'

  doc 'q',
    'Escapes a metric query'
    """
    Use `q` to reference a metric name in the DSL.

    The Graphite API uses unquoted strings to specify metric names and patterns.
    The string argument to `q` will be passed directly to the API.

    For example, `sumSeries(q('twitter.*.tweetcount'))` will be sent as `sumSeries(twitter.*.tweetcount)`.
    """

  fn 'q', (ctx, targets...) ->
    for t in targets
      unless _.isString t
        throw new TypeError "#{t} is not a string"
    Context.value new dsl.type.q targets.map(String)...

  FunctionDocsComponent = React.createClass
    render: ->
      React.DOM.div {className: 'graphite-sphinx-docs'}, [
        React.DOM.div dangerouslySetInnerHTML: __html: @props.docs.docs
        _.map @props.docs.examples, (example) =>
          Builtins.ExampleComponent value: "#{default_target_command} #{JSON.stringify example}", run: false
      ]

  ParameterDocsComponent = React.createClass
    render: -> React.DOM.div {className: 'graphite-sphinx-docs'}
    componentDidMount: ->
      ctx = @props.ctx
      # TODO
      $docs = $(@getDOMNode()).append @props.docs
      $docs.find('a').on 'click', (e) ->
        e.preventDefault()
        href = $(this).attr 'href'
        if href[0] is '#'
          ctx.run "docs '#{decodeURI href[1..]}'"

  component_cmd 'docs', 'Shows the documentation for a Graphite function or parameter', (ctx, name) ->
    if name?
      name = name.to_js_string() if name.to_js_string?
      name = name._lead_context_fn?.name if name._lead_op?
      function_docs = docs.function_docs[name]
      help_components = []
      if function_docs?
        help_components.push Builtins.help_component ctx, "graphite_functions.#{name}"
      name = docs.parameter_doc_ids[name] ? name
      parameter_docs = docs.parameter_docs[name]
      if parameter_docs?
        help_components.push Builtins.help_component ctx, "graphite_parameters.#{name}"

      if help_components.length == 0
        help_components.push 'Documentation not found'
      React.DOM.div null, help_components
    else
      React.DOM.div null,
        React.DOM.h3 {}, 'Functions'
        Builtins.help_component ctx, 'graphite_functions'
        React.DOM.h3 {}, 'Parameters'
        Builtins.help_component ctx, 'graphite_parameters'

  doc 'params',
    'Generates the parameters for a render API call'
    '''
    `params` interprets its arguments in the same way as [`get_data`](help:graphite.get_data),
    but simply returns the arguments that would be passed to the API.

    For example:
    ```
    options areaMode: 'stacked'
    object params sumSeries(q('twitter.*.tweetcount')), width: 1024, height: 768
    ```
    '''

  fn 'params', (ctx, args...) ->
    result = args_to_params ctx, args
    Context.value result

  component_fn 'url', 'Generates a URL for a graph image', (ctx, args...) ->
    params = args_to_params ctx, args
    url = graphite.render_url params
    React.DOM.pre {}, React.DOM.a {href: url, target: 'blank'}, url

  component_fn 'img', 'Renders a graph image', (ctx, args...) ->
    params = args_to_params ctx, args
    url = graphite.render_url params
    deferred = Q.defer()
    promise = deferred.promise.fail -> Q.reject 'Failed to load image'
    Context.AsyncComponent {promise},
      Builtins.ComponentAndError {promise},
        React.DOM.img onLoad: deferred.resolve, onError: deferred.reject, src: url
      Builtins.PromiseStatusComponent {promise, start_time: new Date}

  TimeSeriesTable = React.createClass
    render: ->
      React.DOM.table {}, _.map @props.datapoints, ([value, timestamp]) ->
        time = moment(timestamp * 1000)
        React.DOM.tr {}, [
          React.DOM.th {}, time.format 'MMMM Do YYYY, h:mm:ss a'
          React.DOM.td {className: 'cm-number number'}, value?.toFixed(3) or '(none)'
        ]

  TimeSeriesTableList = React.createClass
    render: ->
      React.DOM.div {}, _.map @props.serieses, (series) ->
        React.DOM.div {}, [
          React.DOM.h3 {}, series.target
          TimeSeriesTable datapoints: series.datapoints
        ]

  component_fn 'table', 'Displays Graphite data in a table', (ctx, args...) ->
    params = args_to_params ctx, args
    props = new Bacon.Model serieses: []
    promise = graphite.get_data(params)
    .then (response) =>
      props.set serieses: response

    Context.AsyncComponent {promise},
      Builtins.ComponentAndError {promise},
        React.PropsModelComponent constructor: TimeSeriesTableList, child_props: props
      Builtins.PromiseStatusComponent {promise, start_time: new Date}

  component_fn 'browser', 'Browse Graphite metrics using a wildcard query', (ctx, query) ->
    finder = graphite.context_fns.find.fn(ctx, query)._lead_context_fn_value # FIXME ew
    finder.clicks.onValue (node) =>
      if node.is_leaf
        ctx.run "q(#{JSON.stringify node.path})"
      else
        ctx.run "browser #{JSON.stringify node.path + '.*'}"
    finder.component


  component_fn 'tree', 'Generates a browsable tree of metrics', (ctx, query) ->
    graphite.MetricTreeComponent {query}

  FindResultsComponent = React.createClass
    render: ->
      query_parts = @props.query.split '.'
      React.DOM.ul {className: 'find-results'}, _.map @props.results, (node) =>
        text = node.path
        text += '.*' unless node.is_leaf
        node_parts = text.split '.'
        React.DOM.li {className: 'cm-string', onClick: => @props.on_click node}, _.map node_parts, (segment, i) ->
          s = segment
          s = '.' + s unless i == 0
          React.DOM.span {className: if segment == query_parts[i] then 'light' else null}, s

  fn 'find', 'Finds Graphite metrics', (ctx, query) ->
    promise = graphite.find(query)
    .then (r) =>
      results.set r.result
      r
    .fail (reason) =>
      Q.reject 'Find request failed'

    clicks = new Bacon.Bus

    results = new Bacon.Model []
    props = Bacon.Model.combine {results, query, on_click: (node) -> clicks.push node}
    component = Context.AsyncComponent {promise},
      Builtins.ComponentAndError {promise},
        React.PropsModelComponent constructor: FindResultsComponent, child_props: props
      Builtins.PromiseStatusComponent {promise, start_time: new Date}

    Context.value {promise, clicks, component}

  fn 'get_data', 'Fetches Graphite metric data', (ctx, args...) ->
    Context.value graphite.get_data graphite.args_to_params {args, default_options: ctx.options()}

  MetricTreeComponent: React.createClass
    render: ->
      Components.TreeComponent
        root: @props.query ? '',
        load: (path) =>
          ctx.run "q(#{JSON.stringify path})"
        load_children: (path) ->
          if path == ''
            subpath = '*'
          else
            subpath = "#{path}.*"
          graphite.find(subpath).get 'result'
        create_node: (props) ->
          if props.node.path == ''
            name = 'All Metrics'
          else
            parts = props.node.path.split '.'
            name = parts[parts.length - 1]
          Components.TreeNodeComponent _.extend({}, props, {name}), name
        create_error_node: (props) ->
          React.DOM.div null,
            React.DOM.i {className: 'fa fa-exclamation-triangle'}
            ' Error loading metric names'

  context_vars: -> dsl.define_functions {}, function_names

  is_pattern: (s) ->
    for c in '*?[{'
      return true if s.indexOf(c) >= 0
    false

  url: (path, params) ->
    base_url = settings.get 'base_url'
    if not base_url?
      throw new Error 'Graphite base_url not set'

    if params?
      query_string = $.param params, true
      "#{base_url}/#{path}?#{query_string}"
    else
      "#{base_url}/#{path}"

  render_url: (params) -> graphite.url 'render', params

  parse_target: (string) -> parser.parse string

  parse_url: (string) ->
    url = new URI string
    query = url.query true
    targets = query.target or []
    targets = [targets] unless _.isArray targets
    targets: _.map targets, graphite.parse_target
    options: _.omit query, 'target'

  parse_error_response: (response) ->
    return response.responseJSON if response.responseJSON?
    return 'request failed' unless response.responseText?
    html = Html.parse_document response.responseText
    pre = html.querySelector 'pre.exception_value'
    if pre?
      # python debug error message
      h1 = html.querySelector 'h1'
      msg = "#{h1.innerText}: #{pre.innerText}"
    else
      # graphite style error message in a pre
      pre = html.querySelector 'pre'
      msg = pre.innerText.trim()
    msg ? 'Unknown error'

  # TODO this is only use for complete
  parse_find_response: (query, response) ->
    parts = query.split '.'
    pattern_parts = parts.map graphite.is_pattern
    list = for node in response
      if node.is_leaf
        node.path
      else
        node.path + '.'
    patterned_list = for path in list
      result = for matched, i in path.split '.'
        if pattern_parts[i]
          parts[i]
        else
          matched
      result.join '.'
    _.uniq patterned_list.concat(list)

  transform_response: (response) ->
    if settings.get('type') == 'lead'
      if response.exceptions.length > 0
        return Q.reject response.exceptions
      _.map _.flatten(_.values(response.results)), ({name, start, step, values}) ->
        target: name
        datapoints: _.map values, (v, i) ->
          [v, start + step * i]
    else
      response

  # returns a promise
  get_data: (params) ->
    params.format = 'json'
    if settings.get('type') == 'lead'
      promise = http.post(graphite.url('execute'), params)
    else
      promise = http.get graphite.render_url(params)

    promise.then graphite.transform_response, (response) -> Q.reject graphite.parse_error_response response

  # returns a promise
  complete: (query) ->
    graphite.find(query + '*')
    .then ({result}) ->
      graphite.parse_find_response query, result

  find: (query) ->
    if settings.get('type') == 'lead'
      http.get(graphite.url 'find', {query}).then (response) ->
        result = _.map response, (m) -> {path: m.name, name: m.name, is_leaf: m['is-leaf']}
        {query, result}
    else
      params =
        query: query
        format: 'completer'
      http.get(graphite.url 'metrics/find', params)
      .then (response) ->
        result = _.map response.metrics, ({path, name, is_leaf}) -> {path: path.replace(/\.$/, ''), name, is_leaf: is_leaf == '1'}
        {query, result}

  suggest_keys: (s) ->
    _.filter _.keys(docs.parameter_docs), (k) -> k.indexOf(s) is 0

  args_to_params: ({args, default_options}) ->
    if args.legnth == 0
      # you're doing it wrong
      {}
    if args.length == 1
      arg = args[0]
      targets = arg.targets ? arg.target
      if targets?
        if arg.options
          options = arg.options
        else
          options = _.clone arg
          delete options.targets
          delete options.target
      else
        targets = args[0]
        options = {}
    else
      last = args[args.length - 1]

      if _.isString(last) or dsl.is_dsl_node(last) or _.isArray last
        targets = args
        options = {}
      else
        [targets..., options] = args

    targets = [targets] unless _.isArray targets
    # flatten one level of nested arrays
    targets = Array.prototype.concat.apply [], targets

    params = _.extend {}, default_options, options
    params.target = (dsl.to_target_string(target) for target in targets)
    params

  has_docs: (name) ->
    docs.parameter_docs[name]? or docs.parameter_doc_ids[name]? or docs.function_docs[name]?

  resolve_documentation_key: (ctx, o) ->
    return null unless o?
    if _.isFunction(o) and dsl.is_dsl_node o
      return ['graphite_functions', o.fn_name]
    if _.isString(o) and docs.parameter_docs[o]
      return ['graphite_parameters', o]

graphite.suggest_strings = graphite.complete

module.exports = graphite
