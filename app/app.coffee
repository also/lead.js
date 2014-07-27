URI = require 'URIjs'
_ = require 'underscore'
React = require 'react'
Notebook = require './notebook'
settings = require './settings'
GitHub = require './github'
Context = require './context'

module_names = ['http', 'dsl', 'graph', 'settings']

imports = [
  'builtins'
  'graphite'
  'opentsdb'
  'github'
  'input'
  'notebook'
  'compat'
]

window.lead = {settings}

imports.push.apply imports, settings.get('app', 'imports') or []
module_names.push.apply imports, settings.get('app', 'module_names') or []

settings.default 'app', 'intro_command', "help 'introduction'"
settings.set 'app', 'paths', 'also',
  site: 'github.com'
  repo: 'also/lead.js'

exports.init_app = (target) ->
  # TODO warn
  try
    _.each JSON.parse(localStorage.getItem 'lead_user_settings'), (v, k) -> settings.user_settings.set k, v
  catch e
    console.error 'failed loading user settings', e

  settings.user_settings.changes.onValue ->
    localStorage.setItem 'lead_user_settings', JSON.stringify settings.user_settings.get()

  app_component = React.DOM.div {className: 'lead'},
    React.DOM.div {className: 'nav-bar'}, 'lead'
    Notebook.NotebookComponent {imports, module_names, init: init_notebook}
  React.renderComponent app_component, target

  window.onhashchange = -> window.location.reload()

init_notebook = (nb) ->
  rc = localStorage.lead_rc
  if rc?
    Notebook.eval_coffeescript_without_input_cell nb, rc

  uri = URI location.href
  fragment = uri.fragment()
  if fragment.length > 0 and fragment[0] == '/'
    path = fragment[1..]
    [repo_name, blob...] = path.split('/')
    repo = settings.get 'app', 'paths', repo_name
    if repo?
      url = "https://#{repo.site}/#{repo.repo}/blob/master/#{blob.join '/'}"
      program = (ctx) ->
        GitHub.context_fns.load.fn ctx, url, run: true
        Context.IGNORE
    else
      program = (ctx) ->
        GitHub.context_fns.gist.fn ctx, path, run: true
        Context.IGNORE
    Notebook.run_without_input_cell nb, null, program

    first_cell = Notebook.add_input_cell nb
    Notebook.focus_cell first_cell

  else
    program = if location.search isnt ''
      atob decodeURIComponent location.search[1..]
    else
      intro_command = settings.get 'app', 'intro_command'

    first_cell = Notebook.add_input_cell nb
    if program? and program != ''
      Notebook.set_cell_value first_cell, program
      Notebook.run first_cell
    else
      Notebook.focus_cell first_cell
