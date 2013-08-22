define (require) ->
  URI = require 'URIjs'
  notebook = require 'notebook'

  module_names = ['http', 'dsl']

  imports = [
    'builtins'
    'graphite'
    'opentsdb'
    'github'
  ]

  init_app: ->
    notebook.init_codemirror()

    $document = $ '#document'

    nb = notebook.create_notebook {imports, module_names}

    nb.done (nb) ->
      $document.append nb.$document
      rc = localStorage.lead_rc
      if rc?
        rc_cell = notebook.add_input_cell nb, code: rc
        notebook.run_cell rc_cell
        notebook.remove_cell rc_cell

      window.onhashchange = -> window.location.reload()

      uri = URI location.href
      fragment = uri.fragment()
      if fragment.length > 0 and fragment[0] == '/'
        id = fragment[1..]
        program = "gist #{JSON.stringify id}, run: true; quiet"
      else
        program = if location.search isnt ''
          atob decodeURIComponent location.search[1..]
        else
          'intro'

      first_cell = notebook.add_input_cell nb, code: program
      notebook.run_cell first_cell
      notebook.focus_cell notebook.add_input_cell nb
