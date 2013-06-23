#= require ../lib/colorbrewer.js
define ->
  colors =
    d3: {}
    brewer: colorbrewer

  for k in ['category10', 'category20', 'category20b', 'category20c']
    # dammit, d3
    colors.d3[k] = d3.scale[k]().range()

  colors
