define (require) ->
  lead = require 'core'
  _ = require 'lib/underscore'
  modules = require 'modules'

  notebook = null
  require ['notebook'], (nb) ->
    notebook = nb

  {fn, cmd, ops} = modules.create()



  ops