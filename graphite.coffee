base_url = 'http://grodan.biz'

lead.graphite =
  url: (path, params) ->
    query_string = $.param params, true
    "#{base_url}/#{path}?#{query_string}"

  render_url: (params) -> lead.graphite.url 'render', params

  get_data: (params, options) ->
    params.format = 'json'
    $.ajax
      url: lead.graphite.render_url params
      dataType: 'json'
      success: options.success

  complete: (query, options) ->
    params = 
      query: encodeURIComponent query
      format: 'completer'

    $.ajax
      url: lead.graphite.url 'metrics/find', params
      dataType: 'json'
      success: options.success

lead.graphite.color_aliases = {
  'black' : [0,0,0],
  'white' : [255,255,255],
  'blue' : [100,100,255],
  'green' : [0,200,0],
  'red' : [200,0,50],
  'yellow' : [255,255,0],
  'orange' : [255, 165, 0],
  'purple' : [200,100,255],
  'brown' : [150,100,50],
  'cyan' : [0,255,255],
  'aqua' : [0,150,150],
  'gray' : [175,175,175],
  'grey' : [175,175,175],
  'magenta' : [255,0,255],
  'pink' : [255,100,100],
  'gold' : [200,200,0],
  'rose' : [200,150,200],
  'darkblue' : [0,0,255],
  'darkgreen' : [0,255,0],
  'darkred' : [255,0,0],
  'darkgray' : [111,111,111],
  'darkgrey' : [111,111,111],
}

lead.graphite.default_graph_options =
  background: 'white',
  foreground: 'black',
  majorline: 'rose',
  minorline: 'grey',
  linecolors: 'blue,green,red,purple,brown,yellow,aqua,grey,magenta,pink,gold,rose'.split(','),
  fontname: 'Sans',
  fontsize: 10,
  fontbold: 'false',
  fontitalic: 'false',

# X-axis configurations (copied from rrdtool, this technique is evil & ugly but effective)
SEC = 1
MIN = 60
HOUR = MIN * 60
DAY = HOUR * 24
WEEK = DAY * 7
MONTH = DAY * 31
YEAR = DAY * 365

lead.graphite.x_axes = [
  {seconds: 0.00,  minorGridUnit: SEC,  minorGridStep: 5,  majorGridUnit: MIN,  majorGridStep: 1,  labelUnit: SEC,  labelStep: 5,  format: "%H:%M:%S", maxInterval: 10*MIN},
  {seconds: 0.07,  minorGridUnit: SEC,  minorGridStep: 10, majorGridUnit: MIN,  majorGridStep: 1,  labelUnit: SEC,  labelStep: 10, format: "%H:%M:%S", maxInterval: 20*MIN},
  {seconds: 0.14,  minorGridUnit: SEC,  minorGridStep: 15, majorGridUnit: MIN,  majorGridStep: 1,  labelUnit: SEC,  labelStep: 15, format: "%H:%M:%S", maxInterval: 30*MIN},
  {seconds: 0.27,  minorGridUnit: SEC,  minorGridStep: 30, majorGridUnit: MIN,  majorGridStep: 2,  labelUnit: MIN,  labelStep: 1,  format: "%H:%M", maxInterval: 2*HOUR},
  {seconds: 0.5,   minorGridUnit: MIN,  minorGridStep: 1,  majorGridUnit: MIN,  majorGridStep: 2,  labelUnit: MIN,  labelStep: 1,  format: "%H:%M", maxInterval: 2*HOUR},
  {seconds: 1.2,   minorGridUnit: MIN,  minorGridStep: 1,  majorGridUnit: MIN,  majorGridStep: 4,  labelUnit: MIN,  labelStep: 2,  format: "%H:%M", maxInterval: 3*HOUR},
  {seconds: 2,     minorGridUnit: MIN,  minorGridStep: 1,  majorGridUnit: MIN,  majorGridStep: 10, labelUnit: MIN,  labelStep: 5,  format: "%H:%M", maxInterval: 6*HOUR},
  {seconds: 5,     minorGridUnit: MIN,  minorGridStep: 2,  majorGridUnit: MIN,  majorGridStep: 10, labelUnit: MIN,  labelStep: 10, format: "%H:%M", maxInterval: 12*HOUR},
  {seconds: 10,    minorGridUnit: MIN,  minorGridStep: 5,  majorGridUnit: MIN,  majorGridStep: 20, labelUnit: MIN,  labelStep: 20, format: "%H:%M", maxInterval: 1*DAY},
  {seconds: 30,    minorGridUnit: MIN,  minorGridStep: 10, majorGridUnit: HOUR, majorGridStep: 1,  labelUnit: HOUR, labelStep: 1,  format: "%H:%M", maxInterval: 2*DAY},
  {seconds: 60,    minorGridUnit: MIN,  minorGridStep: 30, majorGridUnit: HOUR, majorGridStep: 2,  labelUnit: HOUR, labelStep: 2,  format: "%H:%M", maxInterval: 2*DAY},
  {seconds: 100,   minorGridUnit: HOUR, minorGridStep: 2,  majorGridUnit: HOUR, majorGridStep: 4,  labelUnit: HOUR, labelStep: 4,  format: "%a %l%p", maxInterval: 6*DAY},
  {seconds: 255,   minorGridUnit: HOUR, minorGridStep: 6,  majorGridUnit: HOUR, majorGridStep: 12, labelUnit: HOUR, labelStep: 12, format: "%m/%d %l%p", maxInterval: 10*DAY},
  {seconds: 600,   minorGridUnit: HOUR, minorGridStep: 6,  majorGridUnit: DAY,  majorGridStep: 1,  labelUnit: DAY,  labelStep: 1,  format: "%m/%d", maxInterval: 14*DAY},
  {seconds: 600,   minorGridUnit: HOUR, minorGridStep: 12, majorGridUnit: DAY,  majorGridStep: 1,  labelUnit: DAY,  labelStep: 1,  format: "%m/%d", maxInterval: 365*DAY},
  {seconds: 2000,  minorGridUnit: DAY,  minorGridStep: 1,  majorGridUnit: DAY,  majorGridStep: 2,  labelUnit: DAY,  labelStep: 2,  format: "%m/%d", maxInterval: 365*DAY},
  {seconds: 4000,  minorGridUnit: DAY,  minorGridStep: 2,  majorGridUnit: DAY,  majorGridStep: 4,  labelUnit: DAY,  labelStep: 4,  format: "%m/%d", maxInterval: 365*DAY},
  {seconds: 8000,  minorGridUnit: DAY,  minorGridStep: 3.5,majorGridUnit: DAY,  majorGridStep: 7,  labelUnit: DAY,  labelStep: 7,  format: "%m/%d", maxInterval: 365*DAY},
  {seconds: 16000, minorGridUnit: DAY,  minorGridStep: 7,  majorGridUnit: DAY,  majorGridStep: 14, labelUnit: DAY,  labelStep: 14, format: "%m/%d", maxInterval: 365*DAY},
  {seconds: 32000, minorGridUnit: DAY,  minorGridStep: 15, majorGridUnit: DAY,  majorGridStep: 30, labelUnit: DAY,  labelStep: 30, format: "%m/%d", maxInterval: 365*DAY},
  {seconds: 64000, minorGridUnit: DAY,  minorGridStep: 30, majorGridUnit: DAY,  majorGridStep: 60, labelUnit: DAY,  labelStep: 60, format: "%m/%d %Y"},
  {seconds: 100000,minorGridUnit: DAY,  minorGridStep: 60, majorGridUnit: DAY,  majorGridStep: 120,labelUnit: DAY,  labelStep: 120, format: "%m/%d %Y"},
  {seconds: 120000,minorGridUnit: DAY,  minorGridStep: 120,majorGridUnit: DAY,  majorGridStep: 240,labelUnit: DAY,  labelStep: 240, format: "%m/%d %Y"}
]

binary = (x) -> Math.pow 1024, x
si = (x) -> Math.pow 1000, x

lead.graphite.unit_systems =
  'binary': [
    ['Pi', binary 5],
    ['Ti', binary 4],
    ['Gi', binary 3],
    ['Mi', binary 2],
    ['Ki', binary 1]],
  'si': [
    ['P', si 5],
    ['T', si 4],
    ['G', si 3],
    ['M', si 2],
    ['K', si 1]],
  'none' : [],
