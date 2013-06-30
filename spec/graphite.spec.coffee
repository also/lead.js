define (require) ->
  graphite = require 'graphite'

  describe 'graphite', ->
    it 'converts a single string to a single raw string target', ->
      params = graphite.args_to_params args: ['test']
      expect(params.target.length).toBe 1
      expect(params.target[0]).toBe 'test'

    it 'accepts a named single target', ->
      params = graphite.args_to_params args: [target: 'test']
      expect(params.target.length).toBe 1
      expect(params.target[0]).toBe 'test'

    it 'accepts an array of targets', ->
      params = graphite.args_to_params args: [['test.1', 'test.2']]
      expect(params.target.length).toBe 2
      expect(params.target[0]).toBe 'test.1'
      expect(params.target[1]).toBe 'test.2'

    it 'accepts a named list of targets as target:', ->
      params = graphite.args_to_params args: [target: ['test.1', 'test.2']]
      expect(params.target.length).toBe 2
      expect(params.target[0]).toBe 'test.1'
      expect(params.target[1]).toBe 'test.2'

    it 'accepts a named list of targets as targets:', ->
      params = graphite.args_to_params args: [targets: ['test.1', 'test.2']]
      expect(params.target.length).toBe 2
      expect(params.target[0]).toBe 'test.1'
      expect(params.target[1]).toBe 'test.2'

    it 'accepts options as options:', ->
      params = graphite.args_to_params args: [target: 'test', options: {yMax: 9999}]
      expect(params.target.length).toBe 1
      expect(params.target[0]).toBe 'test'
      expect(params.yMax).toBe 9999

    it 'treats everything except targets as options', ->
      params = graphite.args_to_params args: [target: 'test', yMax: 9999]
      expect(params.target.length).toBe 1
      expect(params.target[0]).toBe 'test'
      expect(params.yMax).toBe 9999

    it "doesn't accept a single number", ->
      expect(-> graphite.args_to_params args: [1]).toThrow()

    it "doesn't accept a single object", ->
      expect(-> graphite.args_to_params args: [{}]).toThrow()

    xit "doesn't accept a single array", ->
      expect(-> graphite.args_to_params args: [[]]).toThrow()
