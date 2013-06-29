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
        expect(core.to_target_string fake_function).toBe "'fake_function'"

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

      it 'should not take array arguments', ->
        expect(-> fake_function []).toThrow()

      it 'should not take object arguments', ->
        expect(-> fake_function {}).toThrow()

      it 'should not take null arguments', ->
        expect(-> fake_function null).toThrow()

    describe 'raw strings', ->
      raw_string = null

      beforeEach ->
        raw_string = new core.type.q 'raw_string'

      it 'should be lead nodes', ->
        expect(core.is_lead_node raw_string).toBe true

      it 'should have their value as the target', ->
        expect(core.to_target_string raw_string).toBe 'raw_string'

      it 'should have their invocation as the js string', ->
        expect(core.to_js_string raw_string).toBe 'q("raw_string")'

    describe 'numbers', ->
      number = null

      beforeEach ->
        number = new core.type.n 99

      it 'should be lead nodes', ->
        expect(core.is_lead_node number).toBe true

      it 'should have their value as the target', ->
        expect(core.to_target_string number).toBe '99'

      it 'should have their value as the js string', ->
        expect(core.to_js_string number).toBe '99'

    describe 'booleans', ->
      boolean = null

      beforeEach ->
        boolean = new core.type.b false

      it 'should be lead nodes', ->
        expect(core.is_lead_node boolean).toBe true

      it 'should have their value as the target', ->
        expect(core.to_target_string boolean).toBe 'false'

      it 'should have their value as the js string', ->
        expect(core.to_js_string boolean).toBe 'false'

    describe 'strings', ->
      string = null

      beforeEach ->
        string = new core.type.s 'avocado'

      it 'should be lead nodes', ->
        expect(core.is_lead_node string).toBe true

      it 'should have their quoted value as the target', ->
        expect(core.to_target_string string).toBe "'avocado'"

      it 'should have their json-serialized value as the js string', ->
        expect(core.to_js_string string).toBe '"avocado"'

      it 'should not escape backslashes', ->
        s = new core.type.s '\\'
        expect(core.to_target_string s).not.toMatch /\\\\/

      it 'should not escape a single kind of quotes', ->
        s = new core.type.s '"'
        expect(core.to_target_string s).not.toMatch /\\/
        s = new core.type.s "'"
        expect(core.to_target_string s).not.toMatch /\\/
