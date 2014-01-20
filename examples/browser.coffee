bacon = require 'baconjs'

# an stream of things to search for
search = new bacon.Bus

# a stream of clicks on leaves. our finder is created asynchronously, so we need a bus for clicks
leaf_clicks = new bacon.Bus

# toggle leaf selection
selected_leaves = leaf_clicks.scan {}, (s, name) ->
  if s[name]?
    delete s[name]
  else
    s[name] = true
  s

# a list of the selected metric names
metric_names = selected_leaves.map (s) -> _.keys s

# a list of graphite metrics (raw strings)
targets = metric_names.map (names) -> _.map names, (name) -> q name

# there might be gaps in the data points, so tell graphite to connect the dots
targets = targets.map (targets) -> _.map targets, (target) -> keepLastValue target

# fetch the data. this takes some time, so only keep the result from the most recent request.
target_data = targets.flatMapLatest (t) -> bacon.fromPromise get_data t

# graph the data
@graph.graph target_data

# create an input field. it will reflect the current search
i = text_input()
search.onValue (v) -> i.set v

# the value of our form is the latest user input or clicked search
input_search = search.merge(i.changes()).toProperty()

submit = button 'find'

# send the value of the form when the submit button is clicked
triggered_search = input_search.sampledBy(submit)
search.plug triggered_search

# when searches happen, kick off a finder
live search, (n) ->
  finder = find n
  # send leaf clicks on to our bus
  leaf_clicks.plug finder.clicks.filter('.is_leaf').map('.path')

  # branch clicks are searches
  search.plug finder.clicks.filter((n) -> not n.is_leaf).map((n) -> n.path + '*')

  @add_renderable finder

# kick off a search for the root
search.push '*'
