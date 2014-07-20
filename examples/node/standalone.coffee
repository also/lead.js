fs = require 'fs'
lead = require 'lead.js'
context = lead.require 'context'
CoffeeScriptCell = lead.require 'coffeescript_cell'

script = fs.readFileSync __dirname + '/../random_walks.coffee', encoding: 'utf-8'

context.create_standalone_context(imports: ['compat', 'graph'])
.done (ctx) ->
  context.run_in_context ctx, CoffeeScriptCell.create_fn script
  setTimeout ->
    console.log context.render(ctx).html()
  , 100
