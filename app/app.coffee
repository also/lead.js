URI = require 'URIjs'
_ = require 'underscore'
React = require 'react'
{Route, Routes} = Router = require 'react-router'
makeHref = require 'react-router/modules/helpers/makeHref'
Notebook = require './notebook'
Builtins = require './builtins'
Settings = require './settings'
GitHub = require './github'
Context = require './context'
Builder = require './builder'
Documentation = require './documentation'
Modules = require './modules'
Editor = require './editor'
Components = require './components'
CoffeeScriptCell = require './coffeescript_cell'

module_names = ['http', 'dsl', 'graph', 'settings', 'input', 'notebook']

imports = [
  'builtins.*'
  'server.*'
  'github.*'
  'compat.*',
  'opentsdb.tsd'
]

imports.push (Settings.get('app', 'imports') or [])...
module_names.push _.map(imports, (i) -> i.split('.')[0])...
module_names.push (Settings.get('app', 'module_names') or [])...

Settings.default 'app', 'intro_command', "help 'introduction'"

NotFoundComponent = React.createClass
  displayName: 'NotFoundComponent'
  render: ->
    React.DOM.div {}, "Not Found"

AppComponent = React.createClass
  displayName: 'AppComponent'
  render: ->
    if @props.bodyWrapper
      body = @props.bodyWrapper null, @props.activeRouteHandler()
    else
      body = @props.activeRouteHandler()
    React.DOM.div {className: 'lead'},
      React.DOM.div {className: 'nav-bar'},
        Router.Link {to: 'notebook', className: 'title'}, 'lead'
        React.DOM.div {className: 'menu'},
          Router.Link {to: 'help-index'}, React.DOM.i {className: 'fa fa-question-circle'}
          Router.Link {to: 'settings'}, React.DOM.i {className: 'fa fa-cog'}
      React.DOM.div {className: 'body'},
        body

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
  mixins: [Context.ContextAwareMixin]
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
  run: (value) ->
    Router.transitionTo 'raw_notebook', splat: btoa value
  navigate: (key) ->
    Router.transitionTo 'help', {key}
  render: ->
    # TODO don't lie about class. fix the stylesheet to apply
    React.DOM.div {className: 'help output'},
      Context.TopLevelContextComponent {imports, module_names, context: {run: @run, docs_navigate: @navigate}},
        HelpWrapperComponent {doc_key: @props.params.key}

SettingsComponent = React.createClass
  displayName: 'SettingsComponent'
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
      Context.TopLevelContextComponent {ref: 'ctx'},
        Editor.EditorComponent {run: @save_settings, ref: 'editor', key: 'settings_editor', initial_value}
        Context.ContextOutputComponent {}
      React.DOM.span {className: 'run-button', onClick: => @save_settings()},
        React.DOM.i {className: 'fa fa-floppy-o'}
        ' Save User Settings'

NewNotebookComponent = React.createClass
  displayName: 'NewNotebookComponent'
  render: ->
    intro_command = Settings.get 'app', 'intro_command'
    if intro_command? and intro_command != ''
      SingleCoffeeScriptCellNotebookComponent {value: intro_command}
    else
      Notebook.NotebookComponent {imports, module_names, init: (nb) ->
        Notebook.focus_cell Notebook.add_input_cell nb
      }

GistNotebookComponent = React.createClass
  displayName: 'GistNotebookComponent'
  render: ->
    gist = @props.params.gist
    Notebook.NotebookComponent {imports, module_names, init: (notebook) ->
      Notebook.run_without_input_cell notebook, null, (ctx) ->
        GitHub.context_fns.gist.fn ctx, gist, run: true
        Context.IGNORE

      Notebook.focus_cell Notebook.add_input_cell notebook
    }

Base64EncodedNotebookCellComponent = React.createClass
  displayName: 'Base64EncodedNotebookCellComponent'
  render: ->
    value = atob @props.params.splat
    SingleCoffeeScriptCellNotebookComponent {value}

SingleCoffeeScriptCellNotebookComponent = React.createClass
  displayName: 'SingleCoffeeScriptCellNotebookComponent'
  render: ->
    value = @props.value
    Notebook.NotebookComponent {imports, module_names, init: (notebook) ->
      first_cell = Notebook.add_input_cell notebook
      Notebook.set_cell_value first_cell, value
      Notebook.run first_cell
    }

BuilderAppComponent = React.createClass
  displayName: 'BuilderAppComponent'
  render: ->
    Builder.BuilderComponent {root: @props.query.root}

reset_user_settings = (settings) ->
  Settings.user_settings.set settings

exports.init_app = (target) ->
  # TODO warn
  try
    Settings.user_settings.set JSON.parse(localStorage.getItem 'lead_user_settings')
  catch e
    console.error 'failed loading user settings', e

  Settings.user_settings.changes.onValue ->
    localStorage.setItem 'lead_user_settings', JSON.stringify Settings.user_settings.get()

  publicUrl = Settings.get 'app', 'publicUrl'
  if publicUrl?
    `__webpack_public_path__ = publicUrl`

  extraRoutes = Settings.get('app', 'extraRoutes') or []
  bodyWrapper = Settings.get 'app', 'bodyWrapper'

  raw_cell_value = null
  if location.search isnt ''
    uri = URI location.href
    raw_cell_value = uri.query()
    uri.query null
    window.history.replaceState null, document.title, uri.toString()

  null_route = (fn) -> React.createClass render: -> fn.call(@); null

  routesComponent = Routes null,
    Route {handler: AppComponent, bodyWrapper},
      Route {path: '/', name: 'default', handler: null_route ->
        if raw_cell_value?
          Router.replaceWith '/notebook/raw/' + raw_cell_value
        else
          Router.transitionTo 'notebook'
      }
      Route {name: 'notebook', handler: NewNotebookComponent}
      Route {path: '/notebook/raw/*', name: 'raw_notebook', handler: Base64EncodedNotebookCellComponent}
      Route {path: '/notebook/gist/:gist', name: 'gist_notebook', handler: GistNotebookComponent}
      Route {path: '/builder', handler: BuilderAppComponent}
      Route {path: '/help', name: 'help-index', handler: HelpComponent}
      Route {path: '/help/:key', name: 'help', handler: HelpComponent}
      Route {name: 'settings', handler: SettingsComponent}
      extraRoutes...
      Route {path: '/:gist', name: 'old_gist', handler: null_route -> Router.transitionTo 'gist_notebook', gist: @props.params.gist}

  # TODO handler errors, timeouts
  Modules.init_modules(module_names).finally ->
    React.renderComponent routesComponent, target

exports.raw_cell_url = (value) ->
  URI(makeHref 'raw_notebook', splat: btoa value).absoluteTo(location.href).toString()

window.lead =
  settings: Settings
  init_app: exports.init_app
  Router: Router
  React: React

window.React = React
