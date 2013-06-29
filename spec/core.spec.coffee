define ['core'], (core) ->
  describe 'core', ->
    describe 'functions', ->
      
      fake_function = null

      beforeEach ->
        {fake_function} = core.define_functions {}, ['fake_function']

      it 'should be created', ->
        functions = core.define_functions {}, ['fake_function']
        expect(functions.fake_function).toBeDefined()

      it 'should return', ->
        result = fake_function()
        expect(result).not.toBeNull()

      it 'should be lead nodes', ->
        expect(core.is_lead_node fake_function).toBe true

      it 'should return lead nodes', ->
        result = fake_function()
        expect(core.is_lead_node result).toBe true

      it 'should have their name as a string as the target', ->
        expect(core.to_target_string fake_function).toBe '"fake_function"'

      it 'should return a result that has its invocation as the target string', ->
        result = fake_function()
        expect(core.to_target_string result).toBe 'fake_function()'

      it 'should return a result that has its invocation as the js string', ->
        result = fake_function()
        expect(core.to_js_string result).toBe 'fake_function()'

      it 'should take string arguments', ->
        result = fake_function 'argument'
        expect(core.is_lead_node result).toBe true

      it 'should take numeric arguments', ->
        result = fake_function 19
        expect(core.is_lead_node result).toBe true

      it 'should take boolean arguments', ->
        result = fake_function false
        expect(core.is_lead_node result).toBe true

      it 'should take function arguments', ->
        result = fake_function fake_function
        expect(core.is_lead_node result).toBe true

      it 'should not escape backslashes in strings', ->
        result = fake_function '\\'
        expect(core.to_target_string result).not.toMatch /\\\\/
