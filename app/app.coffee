require('object.assign').shim()

React = require 'react'

# TODO this needs to be exported early. move elsewhere.
exports.AppAwareMixin = AppAwareMixin =
  contextTypes:
    app: React.PropTypes.object


URI = require 'URIjs'
_ = require 'underscore'
Q = require 'q'
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
SettingsComponent = require './settingsComponent'
Modal = require './modal'
AppComponent = require './appComponent'

Settings.default 'app', 'intro_command', "help 'introduction'"

NotFoundComponent = React.createClass
  displayName: 'NotFoundComponent'
  render: ->
    React.DOM.div {}, "Not Found"

initializationPromise = null

HelpPathComponent = React.createClass
  displayName: 'HelpPathComponent'
  render: ->
    path = Documentation.keyToPath @props.doc_key
    paths = _.map [0...path.length], (i) -> {path: path[0..i], segment: path[i]}

    React.DOM.div {className: 'help-path'},
      Documentation.DocumentationLinkComponent {key: 'main'}, 'help'
      _.map paths, ({path, segment}, i) ->
        React.DOM.span {key: i}, ' ',
          React.DOM.i({className: 'fa fa-caret-right'}),
          ' ',
          Documentation.DocumentationLinkComponent {key: path},
            Documentation.keyToString segment

HelpWrapperComponent = React.createClass
  displayName: 'HelpWrapperComponent'
  mixins: [ContextComponents.ContextAwareMixin]
  render: ->
    resolved_key = Documentation.getKey @state.ctx, @props.doc_key
    if resolved_key
      doc = Documentation.getDocumentation resolved_key
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
    {imports, modules} = @context.app
    # TODO don't lie about class. fix the stylesheet to apply
    React.DOM.div {className: 'help output'},
      Context.TopLevelContextComponent {imports, modules, context: {app: @context.app, run: @run, docsNavigate: @navigate}},
        HelpWrapperComponent {doc_key: @props.params.key}

NewNotebookComponent = React.createClass
  displayName: 'NewNotebookComponent'
  mixins: [AppAwareMixin]
  render: ->
    {imports, modules} = @context.app
    intro_command = Settings.get 'app', 'intro_command'
    if intro_command? and intro_command != ''
      SingleCoffeeScriptCellNotebookComponent {value: intro_command}
    else
      Notebook.NotebookComponent {context: {app: @context.app}, imports, modules, init: (nb) ->
        Notebook.focus_cell Notebook.add_input_cell nb
      }

GistNotebookComponent = React.createClass
  displayName: 'GistNotebookComponent'
  mixins: [AppAwareMixin]
  render: ->
    {imports, modules} = @context.app
    gist = @props.params.splat
    Notebook.NotebookComponent {context: {app: @context.app}, imports, modules, init: (notebook) ->
      Notebook.run_without_input_cell notebook, null, (ctx) ->
        GitHub.contextExports.gist.fn(ctx, gist, run: true)
        Context.IGNORE

      Notebook.focus_cell Notebook.add_input_cell notebook
    }

GitHubNotebookComponent = React.createClass
  displayName: 'GitHubNotebookComponent'
  mixins: [AppAwareMixin]
  render: ->
    {imports, modules} = @context.app
    file = @props.params.splat
    Notebook.NotebookComponent {context: {app: @context.app}, imports, modules, init: (notebook) ->
      Notebook.run_without_input_cell notebook, null, (ctx) ->
        GitHub.contextExports.load.fn(ctx, file, run: true)
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
    {imports, modules} = @context.app
    Notebook.NotebookComponent {context: {app: @context.app}, imports, modules, init: (notebook) ->
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

exports.init_app = (target, options={}) ->
  # TODO warn
  try
    Settings.user_settings.set JSON.parse(localStorage.getItem 'lead_user_settings') ? {}
  catch e
    console.error 'failed loading user settings', e

  modules =
    http: require('./http')
    dsl: require('./dsl')
    compat: require('./compat')
    graphing: require('./graphing')
    input: require('./input')
    opentsdb: require('./opentsdb')
    settings: Settings
    context: Context
    builtins: Builtins
    notebook: Notebook
    server: Server
    github: GitHub

  _.extend(modules, options.modules)

  imports = [
    'builtins.*'
    'server.*'
    'github.*'
    'graphing.*',
    'compat.*',
    'opentsdb.tsd'
  ]

  imports.push (Settings.get('app', 'imports') or [])...

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

  app = {imports, modules}

  # TODO handle errors, timeouts
  initializationPromise = Modules.init_modules(modules)
  initializationPromise.fail (e) ->
    console.error 'Failure initializing modules', e
    Modal.pushModal handler: InitializationFailureModal, props: error: e

  routesComponent = Routes null,
    Route {handler: AppComponent, bodyWrapper, app, initializationPromise},
      Route path: '/', name: 'default', handler: null_route ->
        queryKeys = Object.keys(@props.query)
        if queryKeys.length == 1 and @props.query[queryKeys[0]].length == 0
          this.replaceWith '/notebook/raw/' + queryKeys[0]
        else
          this.transitionTo 'notebook'
      Route {name: 'notebook', handler: NewNotebookComponent}
      Route {path: '/notebook/raw/*', name: 'raw_notebook', handler: Base64EncodedNotebookCellComponent, addHandlerKey: true}
      Route {path: '/notebook/gist/*', name: 'gist_notebook', handler: GistNotebookComponent, addHandlerKey: true}
      Route {path: '/notebook/github/*', name: 'github_notebook', handler: GitHubNotebookComponent, addHandlerKey: true}
      Route {path: '/builder', handler: BuilderAppComponent}
      Route {path: '/help', name: 'help-index', handler: HelpComponent}
      Route {path: '/help/:key', name: 'help', handler: HelpComponent, addHandlerKey: true}
      Route {path: '/github/oauth', handler: GitHub.GitHubOAuthComponent, addHandlerKey: true}
      Route {name: 'settings', handler: SettingsComponent}
      extraRoutes...
      Router.NotFoundRoute {handler: NotFoundComponent}

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
