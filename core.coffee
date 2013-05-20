window.lead = {}

process_arg = (arg) ->
  return _lead: arg._lead if arg._lead
  if typeof arg is "number"
    return _lead: ['n', _lead_: arg]
  if toString.call(arg) is '[object String]'
    return _lead: ['s', _lead_: arg]
  throw new Error('illegal argument ' + arg)

lead_fn = (name) ->
  result = (args...) ->
    _lead: ['f', name, (process_arg arg for arg in args)...]
  result._lead = ['i', _lead_: name]
  result

lead.define_functions = (ns, names) ->
  ns[name] = lead_fn name for name in names

lead.to_tree = (node) ->
  if node._lead_?
    return node._lead_
  unless node._lead?
    throw new Error(node + " is not a lead node")
  [type, values...] = node._lead
  [type, (lead.to_tree value for value in values)...]

lead.to_string = (node) ->
  if node._lead_to_string?
    return node._lead_to_string()
  if node._lead_?
    return JSON.stringify node._lead_
  unless node._lead?
    throw new Error(node + " is not a lead node")
  [type, values...] = node._lead
  switch type
    when 'f'
      [name, args...] = values
      "#{name}(#{(lead.to_string a for a in args).join ','})"
    else
      lead.to_string values[0]

lead.is_lead_node = (x) ->
  x._lead or x._lead_
