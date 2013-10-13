define (require) ->
  URI = require 'URIjs'
  notebook = require 'notebook'
  settings = require 'settings'
  config = require 'config'
  github = require 'github'

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

  settings.set 'app', 'intro_command', 'intro'
  settings.set 'app', 'paths', 'also',
    site: 'github.com'
    repo: 'also/lead.js'

  init_app: ->
    notebook.init_codemirror()

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
      $document.append nb.$document
      rc = localStorage.lead_rc
      if rc?
        rc_cell = notebook.add_input_cell nb, code: rc
        notebook.run rc_cell
        notebook.remove_cell rc_cell

      window.onhashchange = -> window.location.reload()

      uri = URI location.href
      fragment = uri.fragment()
      if fragment.length > 0 and fragment[0] == '/'
        path = fragment[1..]
        [repo_name, blob...] = path.split('/')
        repo = settings.get 'app', 'paths', repo_name
        if repo?
          url = "https://#{repo.site}/#{repo.repo}/blob/master/#{blob.join '/'}"
          program = "github.load #{JSON.stringify url}, run: true; quiet"
        else
          program = "gist #{JSON.stringify path}, run: true; quiet"
      else
        program = if location.search isnt ''
          atob decodeURIComponent location.search[1..]
        else
          intro_command = settings.get 'app', 'intro_command'

      first_cell = notebook.add_input_cell nb, code: program
      if program? and program != ''
        notebook.run first_cell
      else
        notebook.focus_cell first_cell
