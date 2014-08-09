acorn = require 'acorn'
walk = require 'acorn/util/walk'
_ = require 'underscore'

exports.mangle = (src) ->
  ast = acorn.parse src, ranges: true, locations: true
  chunks = src.split ''

  source = (node) ->
    chunks.slice(node.range[0], node.range[1]).join ''

  update = (node, s) ->
    chunks[node.range[0]] = s
    for i in [(node.range[0] + 1)...node.range[1]]
      chunks[i] = ''

  global_scope = vars: Object.create(null)
  functions = []

  walk.simple ast,
    ScopeBody: (node, scope) ->
      node.scope = scope
    Function: (node, scope, c) ->
      functions.push node
  , walk.scopeVisitor, global_scope

  _.each functions, (f) ->
    if f.type == 'FunctionExpression'
      param_names = _.pluck(f.params, 'name').join ', '
      if param_names.length > 0
        params = ', ' + param_names
      else
        params = ''
      update f, """
      (function(_lead_unbound_fn) {
        var _lead_restoring_context = _capture_context(ctx);
        var _lead_bound_fn = function(#{param_names}) {
          return _lead_restoring_context(_lead_unbound_fn, this, arguments);
        };
        _lead_bound_fn._lead_unbound_fn = _lead_unbound_fn;
        return _lead_bound_fn;
    })(#{source(f)})
    """

  global_vars: Object.keys global_scope.vars
  source: chunks.join ''

