URI = require 'URIjs'
_ = require 'underscore'
React = require 'react'
{Route, Routes} = Router = require 'react-router'
makeHref = require 'react-router/modules/helpers/makeHref'
Notebook = require './notebook'
Builtins = require './builtins'
settings = require './settings'
GitHub = require './github'
Context = require './context'
Builder = require './builder'
Documentation = require './documentation'

module_names = ['http', 'dsl', 'graph', 'settings', 'input', 'notebook']

imports = [
  'builtins'
  'graphite'
  'opentsdb'
  'github'
  'compat'
]

imports.push.apply imports, settings.get('app', 'imports') or []
module_names.push.apply imports, settings.get('app', 'module_names') or []

settings.default 'app', 'intro_command', "help 'introduction'"

AppComponent = React.createClass
  displayName: 'AppComponent'
  render: ->
    React.DOM.div {className: 'lead'},
      React.DOM.div {className: 'nav-bar'}, 'lead'
        React.DOM.div {className: 'body'},
          this.props.activeRouteHandler()

HelpWrapperComponent = React.createClass
  displayName: 'HelpWrapperComponent'
  mixins: [Context.ContextAwareMixin]
  render: ->
    resolved_key = Documentation.get_key @state.ctx, @props.key
    # FIXME 404 on missing docs
    path = Documentation.key_to_path resolved_key
    paths = _.map [0...path.length], (i) -> {path: path[0..i], segment: path[i]}

    doc = Documentation.get_documentation resolved_key
    React.DOM.div null,
      React.DOM.div null,
        Documentation.DocumentationLinkComponent {key: 'imported_context_fns'}, 'help'
        _.map paths, ({path, segment}) ->
          React.DOM.span null, ' ',
            React.DOM.i({className: 'fa fa-caret-right'}),
            ' ',
            Documentation.DocumentationLinkComponent {key: path},
              Documentation.key_to_string segment
      Documentation.DocumentationItemComponent {ctx: @state.ctx, doc}

HelpComponent = React.createClass
  displayName: 'HelpComponent'
  render: ->
    # TODO don't lie about class. fix the stylesheet to apply
    React.DOM.div {className: 'help output'},
      Context.TopLevelContextComponent {imports, module_names, ref: 'ctx'},
        HelpWrapperComponent {key: @props.params.key}

NewNotebookComponent = React.createClass
  displayName: 'NewNotebookComponent'
  render: ->
    intro_command = settings.get 'app', 'intro_command'
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

exports.init_app = (target) ->
  # TODO warn
  try
    _.each JSON.parse(localStorage.getItem 'lead_user_settings'), (v, k) -> settings.user_settings.set k, v
  catch e
    console.error 'failed loading user settings', e

  settings.user_settings.changes.onValue ->
    localStorage.setItem 'lead_user_settings', JSON.stringify settings.user_settings.get()

  raw_cell_value = null
  if location.search isnt ''
    uri = URI location.href
    raw_cell_value = uri.query()
    uri.query null
    window.history.replaceState null, document.title, uri.toString()

  null_route = (fn) -> React.createClass render: -> fn.call(@); null

  routes = Routes null,
    Route {handler: AppComponent},
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
      Route {path: '/help/:key', name: 'help', handler: HelpComponent}
      Route {path: '/:gist', name: 'old_gist', handler: null_route -> Router.transitionTo 'gist_notebook', gist: @props.params.gist}

  React.renderComponent routes, target

exports.raw_cell_url = (value) ->
  URI(makeHref 'raw_notebook', splat: btoa value).absoluteTo(location.href).toString()

window.lead = {settings, init_app: exports.init_app}

window.React = React
