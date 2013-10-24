fs = require 'fs'
lead = require 'lead.js'
lead.enable_codemirror()
#console.log lead.require 'cm/codemirror'
notebook = lead.require 'notebook'
notebook.init_codemirror()

script = fs.readFileSync './examples/random_walks.coffee', encoding: 'utf-8'

notebook.create_notebook(imports: ['builtins', 'compat'], module_names: ['graph'])
.done (nb) ->
  input = notebook.add_input_cell nb, code: script
  notebook.run input
  setTimeout ->
    console.log nb.$document.html()
    process.exit()
  , 5000
