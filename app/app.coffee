URI = require 'URIjs'
_ = require 'underscore'
Q = require 'q'
React = require 'react'
Bacon = require 'bacon.model'
{Route, Routes} = Router = require 'react-router'
Notebook = require './notebook'
Builtins = require './builtins'
Settings = require './settings'
GitHub = require './github'
Context = require './context'
ContextComponents = require './contextComponents'
Builder = require './builder'
Documentation = require './documentation'
Modules = require './modules'
Editor = require './editor'
Components = require './components'
CoffeeScriptCell = require './coffeescript_cell'
Server = require './server'

Modules.register 'http', require './http'
Modules.register 'dsl', require './dsl'
Modules.register 'settings', Settings
Modules.register 'context', Context
Modules.register 'builtins', Builtins
Modules.register 'notebook', Notebook
require './compat'
require './graphing'
require './input'
require './opentsdb'

Settings.default 'app', 'intro_command', "help 'introduction'"

NotFoundComponent = React.createClass
  displayName: 'NotFoundComponent'
  render: ->
    React.DOM.div {}, "Not Found"

modalModel = new Bacon.Model []

exports.pushModal = (modal) ->
  window.setTimeout ->
    modalModel.modify (v) ->
       v.concat(modal)
  , 0
  modal

exports.removeModal = (modal) ->
  window.setTimeout ->
    modalModel.modify (v) ->
      _.without v, modal
  , 0

AppAwareMixin =
  contextTypes:
    app: React.PropTypes.object

exports.ModalComponent = React.createClass
  render: ->
    modal = @props.modal
    React.DOM.div {},
      if @props.title
        React.DOM.div {className: 'modal-title'}, @props.title
      React.DOM.div {className: 'modal-content'},
        @props.children
      if @props.footer
        React.DOM.div {className: 'modal-footer'}, @props.footer

initializationPromise = null
AppComponent = React.createClass
  displayName: 'AppComponent'
  childContextTypes:
    app: React.PropTypes.object
  getChildContext: ->
    app: @props.app
  getInitialState: ->
    initializationPromise.finally =>
      @setState initializationState: initializationPromise.inspect()
    modal: null
    initializationState: initializationPromise.inspect()
  mixins: [Router.Navigation]
  componentWillMount: ->
    modalModel.onValue (modals) =>
      @setState {modal: modals[modals.length-1]}
  render: ->
    # TODO don't do this :(
    @props.app.appComponent = @

    modal = @state.modal
    # TODO warn on initialization failure
    if @state.initializationState.state == 'pending'
      body = null
    else
      body = @props.activeRouteHandler()
    if @props.bodyWrapper
      body = @props.bodyWrapper null, body
    React.DOM.div {className: 'lead'},
      React.DOM.div {className: 'nav-bar'},
        Router.Link {to: 'notebook', className: 'title'}, 'lead'
        React.DOM.div {className: 'menu'},
          Router.Link {to: 'help-index'}, React.DOM.i {className: 'fa fa-question-circle'}
          Router.Link {to: 'settings'}, React.DOM.i {className: 'fa fa-cog'}
      React.DOM.div {className: 'body'},
        body
      if modal
        React.DOM.div {className: 'modal-bg'},
          React.DOM.div {className: 'modal-fg'},
            modal.handler _.extend {dismiss: -> exports.removeModal(modal)}, modal.props

HelpPathComponent = React.createClass
  displayName: 'HelpPathComponent'
  render: ->
    path = Documentation.key_to_path @props.doc_key
    paths = _.map [0...path.length], (i) -> {path: path[0..i], segment: path[i]}

    React.DOM.div {className: 'help-path'},
      Documentation.DocumentationLinkComponent {key: 'main'}, 'help'
      _.map paths, ({path, segment}) ->
        React.DOM.span null, ' ',
          React.DOM.i({className: 'fa fa-caret-right'}),
          ' ',
          Documentation.DocumentationLinkComponent {key: path},
            Documentation.key_to_string segment

HelpWrapperComponent = React.createClass
  displayName: 'HelpWrapperComponent'
  mixins: [ContextComponents.ContextAwareMixin]
  render: ->
    resolved_key = Documentation.get_key @state.ctx, @props.doc_key
    if resolved_key
      doc = Documentation.get_documentation resolved_key
      React.DOM.div null,
        HelpPathComponent {doc_key: resolved_key}
        Documentation.DocumentationItemComponent {ctx: @state.ctx, doc}
    else
      NotFoundComponent()

HelpComponent = React.createClass
  displayName: 'HelpComponent'
  mixins: [Router.Navigation, AppAwareMixin]
  run: (value) ->
    @transitionTo 'raw_notebook', splat: encodeNotebookValue(value)
  navigate: (key) ->
    @transitionTo 'help', {key}
  render: ->
    {imports, module_names} = @context.app
    # TODO don't lie about class. fix the stylesheet to apply
    React.DOM.div {className: 'help output'},
      Context.TopLevelContextComponent {imports, module_names, context: {app: @context.app, run: @run, docs_navigate: @navigate}},
        HelpWrapperComponent {doc_key: @props.params.key}

SettingsComponent = React.createClass
  displayName: 'SettingsComponent'
  mixins: [AppAwareMixin]
  save_settings: (value) ->
    fn = CoffeeScriptCell.create_fn value ? @refs.editor.get_value()
    ctx = @refs.ctx.get_ctx()
    Context.remove_all_components ctx
    user_settings = fn ctx
    # TODO Context.IGNORE can indicate an error. handle this better
    if user_settings != Context.IGNORE and _.isObject user_settings
      reset_user_settings user_settings
  render: ->
    initial_value = JSON.stringify Settings.user_settings.get_without_overrides(), null, '  '
    # TODO don't lie about class. fix the stylesheet to apply
    React.DOM.div {className: 'settings output'},
      Components.ToggleComponent {title: 'Default Settings'},
        Builtins.ObjectComponent object: Settings.get_without_overrides()
      Context.TopLevelContextComponent {ref: 'ctx', context: {app: @context.app}},
        Editor.EditorComponent {run: @save_settings, ref: 'editor', key: 'settings_editor', initial_value}
        Context.ContextOutputComponent {}
      React.DOM.span {className: 'run-button', onClick: => @save_settings()},
        React.DOM.i {className: 'fa fa-floppy-o'}
        ' Save User Settings'

NewNotebookComponent = React.createClass
  displayName: 'NewNotebookComponent'
  mixins: [AppAwareMixin]
  render: ->
    {imports, module_names} = @context.app
    intro_command = Settings.get 'app', 'intro_command'
    if intro_command? and intro_command != ''
      SingleCoffeeScriptCellNotebookComponent {value: intro_command}
    else
      Notebook.NotebookComponent {context: {app: @context.app}, imports, module_names, init: (nb) ->
        Notebook.focus_cell Notebook.add_input_cell nb
      }

GistNotebookComponent = React.createClass
  displayName: 'GistNotebookComponent'
  mixins: [AppAwareMixin]
  render: ->
    {imports, module_names} = @context.app
    gist = @props.params.splat
    Notebook.NotebookComponent {context: {app: @context.app}, imports, module_names, init: (notebook) ->
      Notebook.run_without_input_cell notebook, null, (ctx) ->
        GitHub.context_fns.gist.fn ctx, gist, run: true
        Context.IGNORE

      Notebook.focus_cell Notebook.add_input_cell notebook
    }

Base64EncodedNotebookCellComponent = React.createClass
  displayName: 'Base64EncodedNotebookCellComponent'
  render: ->
    value = decodeURIComponent(escape(atob(@props.params.splat)))
    SingleCoffeeScriptCellNotebookComponent {value}

SingleCoffeeScriptCellNotebookComponent = React.createClass
  displayName: 'SingleCoffeeScriptCellNotebookComponent'
  mixins: [AppAwareMixin]
  render: ->
    value = @props.value
    {imports, module_names} = @context.app
    Notebook.NotebookComponent {context: {app: @context.app}, imports, module_names, init: (notebook) ->
      first_cell = Notebook.add_input_cell notebook
      Notebook.set_cell_value first_cell, value
      Notebook.run first_cell
    }

# TODO style, copy
InitializationFailureModal = React.createClass
  render: ->
    footer = React.DOM.button {onClick: @props.dismiss}, 'OK'
    exports.ModalComponent {title: 'Lead Failed to Start Properly', footer},
      React.DOM.p {},
        "An error occurred while starting lead. More details may be available in the browser's console. Some features might not be available. Try reloading this page."
      React.DOM.p {style: marginTop: '1em'}, "Message: ", @props.error

BuilderAppComponent = React.createClass
  displayName: 'BuilderAppComponent'
  render: ->
    Builder.BuilderComponent {root: @props.query.root}

reset_user_settings = (settings) ->
  Settings.user_settings.set settings

exports.init_app = (target, options={}) ->
  # TODO warn
  try
    Settings.user_settings.set JSON.parse(localStorage.getItem 'lead_user_settings') ? {}
  catch e
    console.error 'failed loading user settings', e

  module_names = ['http', 'dsl', 'graphing', 'settings', 'input', 'notebook']

  imports = [
    'builtins.*'
    'server.*'
    'github.*'
    'graphing.*',
    'compat.*',
    'opentsdb.tsd'
  ]

  imports.push (Settings.get('app', 'imports') or [])...
  module_names.push _.map(imports, (i) -> i.split('.')[0])...
  module_names.push (Settings.get('app', 'module_names') or [])...

  window.addEventListener 'storage', (e) =>
    if e.key == 'lead_user_settings'
      console.log 'updating user settings'
      try
        Settings.user_settings.set JSON.parse(e.newValue) ? {}
      catch e
        console.error 'failed updating user settings', e

  Settings.user_settings.changes.onValue ->
    localStorage.setItem 'lead_user_settings', JSON.stringify Settings.user_settings.get()

  publicUrl = Settings.get 'app', 'publicUrl'
  if publicUrl?
    `__webpack_public_path__ = publicUrl`

  extraRoutes = options.extraRoutes or []
  bodyWrapper = options.bodyWrapper

  if location.search isnt ''
    uri = URI location.href
    if uri.hash() == ''
      query = encodeURIComponent(uri.query())
    else
      query = uri.query()
    uri.hash("#{uri.hash()}?#{query}")
    uri.query(null)
    window.history.replaceState null, document.title, uri.toString()

  null_route = (fn) ->
    React.createClass
      mixins: [Router.Navigation]
      render: -> fn.call(@); null

  app = {imports, module_names}

  routesComponent = Routes null,
    Route {handler: AppComponent, bodyWrapper, app},
      Route path: '/', name: 'default', handler: null_route ->
        queryKeys = Object.keys(@props.query)
        if queryKeys.length == 1 and @props.query[queryKeys[0]].length == 0
          this.replaceWith '/notebook/raw/' + queryKeys[0]
        else
          this.transitionTo 'notebook'
      Route {name: 'notebook', handler: NewNotebookComponent}
      Route {path: '/notebook/raw/*', name: 'raw_notebook', handler: Base64EncodedNotebookCellComponent, addHandlerKey: true}
      Route {path: '/notebook/gist/*', name: 'gist_notebook', handler: GistNotebookComponent, addHandlerKey: true}
      Route {path: '/builder', handler: BuilderAppComponent}
      Route {path: '/help', name: 'help-index', handler: HelpComponent}
      Route {path: '/help/:key', name: 'help', handler: HelpComponent, addHandlerKey: true}
      Route {path: '/github/oauth', handler: GitHub.GitHubOAuthComponent, addHandlerKey: true}
      Route {name: 'settings', handler: SettingsComponent}
      extraRoutes...
      Router.NotFoundRoute {handler: NotFoundComponent}

  # TODO handle errors, timeouts
  initializationPromise = Modules.init_modules(module_names)
  initializationPromise.fail (e) ->
    console.error 'Failure initializing modules', e
    exports.pushModal handler: InitializationFailureModal, props: error: e

  React.renderComponent routesComponent, target


encodeNotebookValue = (value) ->
  btoa(unescape(encodeURIComponent(value)))

exports.raw_cell_url = (ctx, value) ->
  # TODO don't require appComponent
  encoded = encodeNotebookValue(value)
  URI(ctx.app.appComponent.makeHref 'raw_notebook', splat: encoded).absoluteTo(location.href).toString()

exports.SingleCoffeeScriptCellNotebookComponent = SingleCoffeeScriptCellNotebookComponent

window.lead =
  settings: Settings
  init_app: exports.init_app
  Router: Router
  React: React

window.React = React
