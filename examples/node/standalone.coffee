fs = require 'fs'
React = require 'react'
lead = require 'lead.js'
Context = lead.require 'context'
CoffeeScriptCell = lead.require 'coffeescript_cell'

script = fs.readFileSync __dirname + '/../random_walks.coffee', encoding: 'utf-8'

context = Context.create_standalone_context(imports: ['compat'])
Context.run_in_context context, CoffeeScriptCell.create_fn script
# FIXME doesn't render graph, Q logs error
console.log React.renderComponentToString context.component
