URI = require 'URIjs'
_ = require 'underscore'
$ = require 'jquery'
React = require 'react'
notebook = require './notebook'
settings = require './settings'
config = require './config'
github = require './github'

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

imports.push.apply imports, settings.get('app', 'imports') or []
module_names.push.apply imports, settings.get('app', 'module_names') or []

settings.default 'app', 'intro_command', "help 'introduction'"
settings.set 'app', 'paths', 'also',
  site: 'github.com'
  repo: 'also/lead.js'

exports.init_app = ->
  $document = $ '#document'

  # TODO warn
  try
    _.each JSON.parse(localStorage.getItem 'lead_user_settings'), (v, k) -> settings.user_settings.set k, v
  catch e
    console.error 'failed loading user settings', e
  settings.user_settings.changes.onValue ->
    localStorage.setItem 'lead_user_settings', JSON.stringify settings.user_settings.get()

  nb = notebook.create_notebook {imports, module_names}

  nb.done (nb) ->
    React.renderComponent nb.component, $document.get 0
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
        program = ->
          @github.load url, run: true
      else
        program = ->
          @github.gist path, run: true
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
