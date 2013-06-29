define (require) ->
  _ = require 'lib/underscore'

  lead = version: 1

  lead_type = ->

  create_type = (n, parent) ->
    t = (@values...) -> @type = n
    t.prototype = new parent
    lead_type[n] = t

  lead.type = lead_type

  # Create the types:
  #  f: function invocation
  #  q: raw string
  #  b: boolean
  #  n: number
  #  s: string
  #  i: identifier
  create_type n, lead.type for n in "pfqi"

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

  # numbers, strings, and booleans use json serialization
  lead.type.p::to_js_string =
  lead.type.p::to_target_string = ->
    JSON.stringify @values[0]

  create_type n, lead.type.p for n in "nsb"

  # Graphite doesn't support escaped quotes in strings, so avoid including any if possible.
  lead.type.s::to_target_string = ->
    s = @values[0]
    if s.indexOf('"') >= 0 or s.indexOf("'") < 0
      quoteChar = "'"
    else
      quoteChar = '"'
    quoteChar + s.replace(quoteChar, "\\#{quoteChar}") + quoteChar

  lead.type.i::to_target_string = lead.type.s::to_target_string
  lead.type.i::to_js_string = ->
    @values[0]

  process_arg = (arg) ->
    return arg if arg instanceof lead.type
    if typeof arg is "number"
      return new lead.type.n arg
    if _.isString arg
      return new lead.type.s arg
    if _.isBoolean arg
      return new lead.type.b arg
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
