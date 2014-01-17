# TODO
# this is a shim because bacon.model requires 'bacon', but the npm module is 'baconjs' and map doesn't seem to work in the r.js optimized file
define (require) ->
  require 'baconjs'
