define (require) ->
  _ = require 'lib/underscore'

  lead = version: 1

  lead_type = ->

  create_type = (n, parent) ->
    t = (@values...) -> @type = n
    t.prototype = new parent
    lead_type[n] = t

  lead.type = lead_type

  create_type n, lead.type for n in "pfq"
  lead.type.p::to_js_string =
  lead.type.p::to_target_string = ->
    JSON.stringify @values[0]

  lead.type.f::to_target_string = ->
    [name, args...] = @values
    "#{name}(#{(a.to_target_string() for a in args).join ','})"

  lead.type.f::to_js_string = ->
    [name, args...] = @values
    "#{name}(#{(a.to_js_string() for a in args).join ','})"

  lead.type.q::to_target_string = ->
    @values.join ','

  lead.type.q::to_js_string = ->
    "q(#{(@values.map JSON.stringify).join ', '})"

  create_type n, lead.type.p for n in "nsi"
  lead.type.i::to_js_string = ->
    @values[0]

  process_arg = (arg) ->
    return arg if arg instanceof lead.type
    if typeof arg is "number"
      return new lead.type.n arg
    if _.isString arg
      return new lead.type.s arg
    throw new TypeError('illegal argument ' + arg)

  lead_fn = (name) ->
    result = (args...) ->
      new lead.type.f name, (process_arg arg for arg in args)...
    result.type = 'i'
    result.name = name
    result.values = [name]
    result.__proto__ = new lead.type.i

    result

  lead.define_functions = (ns, names) ->
    ns[name] = lead_fn name for name in names
    ns

  lead.to_string = (node) ->
    unless node instanceof lead.type
      throw new TypeError(node + " is not a lead node")
    node.to_target_string()

  lead.to_target_string = (node) ->
    if _.isString node
      node
    else
      lead.to_string node

  lead.to_js_string = (node) ->
    node.to_js_string()

  lead.is_lead_node = (x) ->
    x instanceof lead.type

  lead