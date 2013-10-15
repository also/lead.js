define (require) ->
  expect = require 'expect'
  notebook = require 'notebook'

  describe 'notebooks', ->
    it 'can be created', ->
      nb = notebook.create_notebook({})
