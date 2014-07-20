fs = require 'fs'
lead = require 'lead.js'
notebook = lead.require 'notebook'
React = require 'react'

script = fs.readFileSync __dirname + '/../random_walks.coffee', encoding: 'utf-8'

notebook.create_notebook(imports: ['builtins', 'compat'], module_names: ['graph'])
.done (nb) ->
  input = notebook.add_input_cell nb, code: script
  notebook.run input
  setTimeout ->
    console.log React.renderComponentToStaticMarkup nb.component
    process.exit()
  , 500
