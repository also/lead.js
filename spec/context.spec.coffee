define (require) ->
  $ = require 'jquery'
  context = require 'context'

  describe 'contexts', ->
  	$el = null
  	beforeEach ->
      $el = $ '<div/>'

  	it 'can be created', ->
  	  context.create_run_context $el

    it 'can output', ->
      run_context = context.create_run_context $el
      html = 'hello, world'
      run_context.output html
      expect($el.text()).toBe html
