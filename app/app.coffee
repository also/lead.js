URI = require 'URIjs'
_ = require 'underscore'
React = require 'react'
notebook = require './notebook'
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

  nb = notebook.create_notebook {imports, module_names}

  app_component = React.DOM.div {className: 'lead'},
    React.DOM.div {className: 'nav-bar'}, 'lead'
    React.DOM.div {className: 'document cm-s-idle'}, nb.component
  React.renderComponent app_component, target
  rc = localStorage.lead_rc
  if rc?
    notebook.eval_coffeescript_without_input_cell nb, rc

  window.onhashchange = -> window.location.reload()

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
    notebook.run_without_input_cell nb, null, program

    first_cell = notebook.add_input_cell nb
    notebook.focus_cell first_cell

  else
    program = if location.search isnt ''
      atob decodeURIComponent location.search[1..]
    else
      intro_command = settings.get 'app', 'intro_command'

    first_cell = notebook.add_input_cell nb
    if program? and program != ''
      notebook.set_cell_value first_cell, program
      notebook.run first_cell
    else
      notebook.focus_cell first_cell
