require('object.assign').shim()

React = require 'react'

# TODO this needs to be exported early. move elsewhere.
exports.AppAwareMixin = AppAwareMixin =
  contextTypes:
    app: React.PropTypes.object


URI = require 'URIjs'
_ = require 'underscore'
Q = require 'q'
{Route, Routes} = Router = require 'react-router'
Settings = require './settings'
Context = require './context'
Modules = require './modules'
Modal = require './modal'
AppRoutes = require './routes'

Defaults = require './defaultApp'

Settings.default 'app', 'intro_command', "help 'introduction'"

# TODO style, copy
InitializationFailureModal = React.createClass
  render: ->
    footer = React.DOM.button {onClick: @props.dismiss}, 'OK'
    Modal.ModalComponent {title: 'Lead Failed to Start Properly', footer},
      React.DOM.p {},
        "An error occurred while starting lead. More details may be available in the browser's console. Some features might not be available. Try reloading this page."
      React.DOM.p {style: marginTop: '1em'}, "Message: ", @props.error.message || @props.error

bindUserSettingsToLocalStorage = (key) =>
  # TODO warn
  try
    Settings.user_settings.set JSON.parse(localStorage.getItem key) ? {}
  catch e
    console.error 'failed loading user settings', e

  window.addEventListener 'storage', (e) =>
    if e.key == key
      console.log 'updating user settings'
      try
        Settings.user_settings.set JSON.parse(e.newValue) ? {}
      catch e
        console.error 'failed updating user settings', e

  Settings.user_settings.changes.onValue ->
    localStorage.setItem key, JSON.stringify Settings.user_settings.get()

exports.init_app = (target, options={}) ->
  bindUserSettingsToLocalStorage('lead_user_settings')

  publicUrl = Settings.get 'app', 'publicUrl'
  if publicUrl?
    `__webpack_public_path__ = publicUrl`

  modules = _.extend({}, Defaults.modules, options.modules)
  imports = Defaults.imports.slice()
  imports.push (Settings.get('app', 'imports') or [])...
  app = {imports, modules}

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

  # TODO handle errors, timeouts
  initializationPromise = Modules.init_modules(modules)
  initializationPromise.fail (e) ->
    console.error 'Failure initializing modules', e
    Modal.pushModal handler: InitializationFailureModal, props: error: e

  React.renderComponent AppRoutes({bodyWrapper, app, initializationPromise, extraRoutes}), target

encodeNotebookValue = (value) ->
  btoa(unescape(encodeURIComponent(value)))

exports.raw_cell_url = (ctx, value) ->
  # TODO don't require appComponent
  encoded = encodeNotebookValue(value)
  URI(ctx.app.appComponent.makeHref 'raw_notebook', splat: encoded).absoluteTo(location.href).toString()

window.lead =
  settings: Settings
  init_app: exports.init_app
  Router: Router
  React: React

window.React = React
