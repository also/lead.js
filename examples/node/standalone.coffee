lead = require 'lead.js'
context = lead.require 'context'

context.create_standalone_context()
.done (ctx) ->
  ctx.help 'introduction'
  console.log context.render(ctx).html()
