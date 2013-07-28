define (require) ->
  _ = require 'underscore'

  dsl_type = ->
  dsl = type: dsl_type

  create_type = (n, parent) ->
    t = (@values...) -> @type = n
    t.prototype = new parent
    dsl_type[n] = t

  # Create the types:
  #  f: function invocation
  #  q: raw string
  #  b: boolean
  #  n: number
  #  s: string
  #  i: identifier
  create_type n, dsl.type for n in "pfqi"

  dsl.type.f::to_target_string = ->
    [name, args...] = @values
    "#{name}(#{(a.to_target_string() for a in args).join ','})"

  dsl.type.f::to_js_string = ->
    [name, args...] = @values
    "#{name}(#{(a.to_js_string() for a in args).join ','})"

  dsl.type.q::to_target_string = ->
    @values.join ','

  dsl.type.q::to_js_string = ->
    "q(#{(@values.map JSON.stringify).join ', '})"

  # numbers, strings, and booleans use json serialization
  dsl.type.p::to_js_string =
  dsl.type.p::to_target_string = ->
    JSON.stringify @values[0]

  create_type n, dsl.type.p for n in "nsb"

  # Graphite doesn't support escaped quotes in strings, so avoid including any if possible.
  dsl.type.s::to_target_string = ->
    s = @values[0]
    if s.indexOf('"') >= 0 or s.indexOf("'") < 0
      quoteChar = "'"
    else
      quoteChar = '"'
    quoteChar + s.replace(quoteChar, "\\#{quoteChar}") + quoteChar

  dsl.type.i::to_target_string = dsl.type.s::to_target_string
  dsl.type.i::to_js_string = ->
    @values[0]

  process_arg = (arg) ->
    return arg if arg instanceof dsl.type
    if typeof arg is "number"
      return new dsl.type.n arg
    if _.isString arg
      return new dsl.type.s arg
    if _.isBoolean arg
      return new dsl.type.b arg
    throw new TypeError('illegal argument ' + arg)

  dsl_fn = (name) ->
    result = (args...) ->
      new dsl.type.f name, (process_arg arg for arg in args)...
    result.type = 'i'
    result.name = name
    result.values = [name]
    result.__proto__ = new dsl.type.i

    result

  dsl.define_functions = (ns, names) ->
    ns[name] = dsl_fn name for name in names
    ns

  dsl.to_string = (node) ->
    unless node instanceof dsl.type
      throw new TypeError(node + " is not a dsl node")
    node.to_target_string()

  dsl.to_target_string = (node) ->
    if _.isString node
      node
    else
      dsl.to_string node

  dsl.to_js_string = (node) ->
    node.to_js_string()

  dsl.is_dsl_node = (x) ->
    x instanceof dsl.type

  dsl
