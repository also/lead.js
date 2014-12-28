###
context_fns: context functions collected from all modules. unbound
imported_context_fns: context_fns + the fns from all modules listed in imports
fns: imported_context_fns, bound to the scope.ctx
###

_ = require 'underscore'
Q = require  'q'
Bacon = require 'bacon.model'
React = require 'react/addons'
ContextComponents = require './contextComponents'
Components = require './components'
Builtins = require './builtins'
Modules = require './modules'

ignore = new Object

running_context_binding = null

value = (value) -> _lead_context_fn_value: value

# statement result handlers. return truthy if handled.
ignored = (ctx, object) -> object == ignore

handle_cmd = (ctx, object) ->
  if (op = object?._lead_context_fn)?
    if op.cmd_fn?
      op.cmd_fn.call null, ctx
      true
    else
      add_component ctx, React.DOM.div null,
        "Did you forget to call a function? \"#{object._lead_context_name}\" must be called with arguments."
        Builtins.help_component ctx, object
      true

handle_module = (ctx, object) ->
  if object?._lead_context_name
    add_component ctx, React.DOM.div null,
      "#{object._lead_context_name} is a module."
      Builtins.help_component ctx, object
    true

handle_using_extension = (ctx, object) ->
  handlers = collect_extension_points ctx, 'context_result_handler'
  _.find handlers, (handler) -> handler ctx, object

handle_promise = (ctx, object) ->
  if Q.isPromise object
    add_component ctx, Builtins.PromiseComponent {promise: object}

handleObservable = (ctx, object) ->
  if object instanceof Bacon.Observable
    add_component ctx, Builtins.ObservableComponent observable: object

handleComponent = (ctx, object) ->
  if React.isValidComponent object
    add_component ctx, object

handle_any_object = (ctx, object) ->
  add_component ctx, Builtins.ObjectBrowserComponent {object}
  true

# TODO make this configurable
result_handlers = [
  ignored
  handle_cmd
  handle_module
  handle_using_extension
  handle_promise
  handleObservable
  handleComponent
  handle_any_object
]

display_object = (ctx, object) ->
  for handler in result_handlers
    return if handler ctx, object

# extension point
resolve_documentation_key = (ctx, o) ->
  if name = o?._lead_context_name
    if fn = o._lead_context_fn
      [fn.module_name, fn.name]
    else
      name

collect_extension_points = (context, extension_point) ->
  Modules.collect_extension_points context.modules, extension_point

collect_context_vars = (context) ->
  module_vars = (module, name) ->
    vars = module.context_vars
    if _.isFunction vars
      vars = vars.call context
    [name, vars ? {}]

  _.object _.filter _.map(context.modules, module_vars), ([n, f]) -> f

collect_context_fns = (context) ->
  _.object _.filter _.map(context.modules, (module, name) -> [name, module.context_fns ? {}]), ([n, f]) -> f

is_run_context = (o) ->
  o?.component_list?

bind_fn_to_context = (ctx, fn) ->
  (args...) ->
    args.unshift ctx
    fn.apply ctx, args

bind_context_fns = (target, scope, fns, name_prefix='') ->
  for k, o of fns
    do (k, o) ->
      if _.isFunction o.fn
        name = "#{name_prefix}#{k}"
        wrapped_fn = ->
          o.fn.apply(null, arguments)?._lead_context_fn_value ? ignore

        bind = ->
          bound = bind_fn_to_context scope.ctx, wrapped_fn
          bound._lead_context_fn = o
          bound._lead_context_name = name
          bound
        Object.defineProperty target, k, get: bind, enumerable: true
      else
        target[k] = bind_context_fns {_lead_context_name: k}, scope, o, k + '.'

  target

find_in_scope = (ctx, name) ->
  ctx.scope[name]

AsyncComponent = React.createClass
  displayName: 'AsyncComponent'
  mixins: [ContextComponents.ContextAwareMixin]
  componentWillMount: ->
    register_promise @state.ctx, @props.promise
  componentWillUnmount: ->
    # FIXME should unregister
  render: ->
    React.DOM.div null, @props.children


ContextComponent = React.createClass
  displayName: 'ContextComponent'
  mixins: [ContextComponents.ContextRegisteringMixin]
  propTypes:
    ctx: (c) -> throw new Error("context required") unless is_run_context c['ctx']
  render: ->
    ContextLayoutComponent {ctx: @props.ctx}


ContextLayoutComponent = React.createClass
  displayName: 'ContextLayoutComponent'
  mixins: [Components.ObservableMixin]
  propTypes:
    ctx: (c) -> throw new Error("context required") unless is_run_context c['ctx']
  get_observable: (props) -> props.ctx.component_list.model
  render: ->
    children = _.map @state.value, ({key, component}) ->
      if _.isFunction(component)
        c = component()
      else
        c = component
      React.addons.cloneWithProps c, {key}
    ctx = @props.ctx
    ctx.layout _.extend {children}, ctx.layout_props


ContextOutputComponent = React.createClass
  displayName: 'ContextOutputComponent'
  mixins: [ContextComponents.ContextAwareMixin]
  render: -> ContextLayoutComponent ctx: @state.ctx


TopLevelContextComponent = React.createClass
  displayName: 'TopLevelContextComponent'
  getInitialState: ->
    # FIXME #175 props can change
    ctx = create_standalone_context @props
    {ctx}
  get_ctx: ->
    @state.ctx
  render: ->
    ContextComponents.ComponentContextComponent {children: @props.children, ctx: @state.ctx}


# the base context contains the loaded modules, and the list of modules to import into every context
create_base_context = ({modules, module_names, imports}={}) ->
  modules = _.extend({context: exports}, modules)
  # TODO find a better home for repl vars
  {modules, imports, repl_vars: {}, prop_vars: {}}

importInto = (obj, target, path) ->
  segments = path.split('.')
  lastSegment = segments[segments.length - 1]
  if lastSegment = '*'
    wildcard = true
    segments.pop()
  try
    value = _.reduce segments, ((result, key) -> result[key]), obj
  catch
    value = null
  unless value?
    throw new Error("can't import #{path}")
  if wildcard
    _.extend target, value
  else
    target[lastSegment] = value

# the XXX context contains all the context functions and vars. basically, everything needed to support
# an editor
create_context = (base) ->
  context_fns = collect_context_fns base
  imported_context_fns = _.clone context_fns
  _.each base.imports, _.partial importInto, context_fns, imported_context_fns

  scope =
    _capture_context: (fn) ->
      restoring_context = capture_context(scope.ctx)
      (args...) ->
        restoring_context => fn.apply @, args

  bind_context_fns scope, scope, imported_context_fns

  vars = collect_context_vars base
  imported_vars = {}
  _.each base.imports, _.partial importInto, vars, imported_vars
  _.extend scope, imported_vars

  context = _.extend {}, base,
    imported_context_fns: imported_context_fns
    imported_vars: imported_vars
    scope: scope

# FIXME figure out a real check for a react component
is_component = (o) -> o?.__realComponentInstance?

component_list = ->
  components = []
  componentId = 1
  model = new Bacon.Model []

  model: model
  add_component: (c) ->
    components.push
      component: c
      key: componentId++
    model.set components.slice()
  empty: ->
    components = []
    model.set []

add_component = (ctx, component) ->
  ctx.component_list.add_component component

remove_all_components = (ctx) ->
  ctx.component_list.empty()

# creates a nested context, adds it to the component list, and applies the function to it
nested_item = (ctx, fn, args...) ->
  nested_context = create_nested_context ctx
  add_component ctx, nested_context.component
  call_in_ctx nested_context, fn, args


# used by
# * apply_to
#   * grid and flow layouts (for evaled functions)
#   * nested_item
#   * capture_context
#     * keeping_context
#   * Input.live
#   * Markdown.InlineExampleComponent
# * in_running_context
#
splice_ctx = (ctx, target_ctx, fn, args=[]) ->
  previous_context = target_ctx.scope.ctx
  target_ctx.scope.ctx = ctx
  fn = fn._lead_unbound_fn ? fn
  try
    fn ctx, args...
  finally
    target_ctx.scope.ctx = previous_context


apply_to = (ctx, fn, args) ->
  fn = fn._lead_unbound_fn ? fn
  call_in_ctx ctx, (ctx) -> fn.apply ctx, args


call_in_ctx = (ctx, fn, args) ->
  splice_ctx ctx, ctx, fn, args


# returns a function that calls its argument in the current context
capture_context = (ctx) ->
  running_context = running_context_binding
  (fn, args) ->
    previous_running_context_binding = running_context_binding
    running_context_binding = running_context
    try
      call_in_ctx ctx, fn, args
    finally
      running_context_binding = previous_running_context_binding


# wraps a function so that it is called in the current context
keeping_context = (ctx, fn) ->
  restoring_context = capture_context ctx
  ->
    restoring_context fn, arguments


in_running_context = (ctx, fn, args) ->
  throw new Error 'no active running context. did you call an async function without keeping the context?' unless running_context_binding?
  splice_ctx running_context_binding, ctx, fn, args

# TODO this is an awful name
context_run_context_prototype =
  options: -> @current_options


register_promise = (ctx, promise) ->
  ctx.asyncs.push 1
  promise.finally =>
    ctx.asyncs.push -1
    ctx.changes.push true

create_run_context = (extra_contexts) ->
  run_context_prototype = _.extend {}, extra_contexts..., context_run_context_prototype
  result = create_nested_context run_context_prototype
  if result.mainLayout?
    result.layout = result.mainLayout

  asyncs = new Bacon.Bus
  changes = new Bacon.Bus
  changes.plug result.component_list.model

  _.defaults result,
    current_options: {}
    changes: changes
    asyncs: asyncs
    pending: asyncs.scan 0, (a, b) -> a + b

  result.scope.ctx = result


create_nested_context = (parent, overrides) ->
  new_context = _.extend Object.create(parent), {layout: Components.SimpleLayoutComponent}, overrides
  new_context.component_list = component_list()
  new_context.component = -> ContextComponent ctx: new_context

  new_context


create_standalone_context = ({imports, module_names, modules, context}={}) ->
  base_context = create_base_context({imports: ['builtins'].concat(imports or []), module_names, modules})
  create_run_context [context ? {}, create_context base_context]


scoped_eval = (ctx, string, var_names=[]) ->
  if _.isFunction string
    string = "(#{string}).apply(this);"
  _.each var_names, (name) ->
    ctx.repl_vars[name] ?= undefined
  (->
    `with (ctx.scope) { with (ctx.repl_vars) {
      return eval(string);
    }}`
    return # this return is just to trick the coffeescript compiler, which doesn't see the return in backticks above
  ).call(ctx)


eval_in_context = (run_context, string) ->
  run_in_context run_context, (ctx) -> scoped_eval ctx, string

run_in_context = (run_context, fn) ->
  try
    previous_running_context_binding = running_context_binding
    running_context_binding = run_context
    result = fn run_context
    display_object run_context, result
  finally
    running_context_binding = previous_running_context_binding

_.extend exports, {
  create_base_context,
  create_context,
  create_run_context,
  create_standalone_context,
  create_nested_context,
  run_in_context,
  eval_in_context,
  collect_extension_points,
  find_in_scope,
  is_run_context,
  in_running_context,
  keeping_context,
  register_promise,
  apply_to,
  value,
  scoped_eval,
  add_component,
  remove_all_components,
  nested_item,
  resolve_documentation_key,
  AsyncComponent,
  TopLevelContextComponent,
  ContextComponent,
  ContextOutputComponent,
  IGNORE: ignore
}
