define (require) ->
  $ = require 'jquery'
  context = require 'context'

  describe 'contexts', ->
    it 'can be created', ->
      context.create_run_context []

    it 'can output', ->
      run_context = context.create_run_context []
      html = 'hello, world'
      run_context.output html
      $el = context.render run_context
      expect($el.text()).toBe html
