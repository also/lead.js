fs = require 'fs'
lead = require 'lead.js'
React = require 'react'
Context = lead.require 'context'
CoffeeScriptCell = lead.require 'coffeescript_cell'

script = fs.readFileSync __dirname + '/../random_walks.coffee', encoding: 'utf-8'

context = Context.create_standalone_context(imports: ['compat'])
Context.run_in_context context, CoffeeScriptCell.create_fn script
# FIXME doesn't render graph, Q logs error
elt = document.createElement 'div'
React.render context.component, elt
setTimeout ->
	console.log elt.innerHTML
, 100
