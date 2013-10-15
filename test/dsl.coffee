define (require) ->
  expect = require 'expect'
  dsl = require 'dsl'
  describe 'dsl', ->
    describe 'functions', ->
      fake_function = null

      beforeEach ->
        {fake_function} = dsl.define_functions {}, ['fake_function']

      it 'should be created', ->
        functions = dsl.define_functions {}, ['fake_function']
        expect(functions.fake_function).to.be.ok()

      it 'should return', ->
        result = fake_function()
        expect(result).not.to.be(null)

      it 'should be dsl nodes', ->
        expect(dsl.is_dsl_node fake_function).to.be true

      it 'should return dsl nodes', ->
        result = fake_function()
        expect(dsl.is_dsl_node result).to.be true

      it 'should have their name as a string as the target', ->
        expect(dsl.to_target_string fake_function).to.be "'fake_function'"

      it 'should return a result that has its invocation as the target string', ->
        result = fake_function()
        expect(dsl.to_target_string result).to.be 'fake_function()'

      it 'should return a result that has its invocation as the js string', ->
        result = fake_function()
        expect(dsl.to_js_string result).to.be 'fake_function()'

      it 'should take string arguments', ->
        result = fake_function 'argument'
        expect(dsl.is_dsl_node result).to.be true

      it 'should take numeric arguments', ->
        result = fake_function 19
        expect(dsl.is_dsl_node result).to.be true

      it 'should take boolean arguments', ->
        result = fake_function false
        expect(dsl.is_dsl_node result).to.be true

      it 'should take function arguments', ->
        result = fake_function fake_function
        expect(dsl.is_dsl_node result).to.be true

      it 'should not take array arguments', ->
        expect(-> fake_function []).to.throwException()

      it 'should not take object arguments', ->
        expect(-> fake_function {}).to.throwException()

      it 'should not take null arguments', ->
        expect(-> fake_function null).to.throwException()

    describe 'raw strings', ->
      raw_string = null

      beforeEach ->
        raw_string = new dsl.type.q 'raw_string'

      it 'should be dsl nodes', ->
        expect(dsl.is_dsl_node raw_string).to.be true

      it 'should have their value as the target', ->
        expect(dsl.to_target_string raw_string).to.be 'raw_string'

      it 'should have their invocation as the js string', ->
        expect(dsl.to_js_string raw_string).to.be 'q("raw_string")'

    describe 'numbers', ->
      number = null

      beforeEach ->
        number = new dsl.type.n 99

      it 'should be dsl nodes', ->
        expect(dsl.is_dsl_node number).to.be true

      it 'should have their value as the target', ->
        expect(dsl.to_target_string number).to.be '99'

      it 'should have their value as the js string', ->
        expect(dsl.to_js_string number).to.be '99'

    describe 'booleans', ->
      boolean = null

      beforeEach ->
        boolean = new dsl.type.b false

      it 'should be dsl nodes', ->
        expect(dsl.is_dsl_node boolean).to.be true

      it 'should have their value as the target', ->
        expect(dsl.to_target_string boolean).to.be 'false'

      it 'should have their value as the js string', ->
        expect(dsl.to_js_string boolean).to.be 'false'

    describe 'strings', ->
      string = null

      beforeEach ->
        string = new dsl.type.s 'avocado'

      it 'should be dsl nodes', ->
        expect(dsl.is_dsl_node string).to.be true

      it 'should have their quoted value as the target', ->
        expect(dsl.to_target_string string).to.be "'avocado'"

      it 'should have their json-serialized value as the js string', ->
        expect(dsl.to_js_string string).to.be '"avocado"'

      it 'should not escape backslashes', ->
        s = new dsl.type.s '\\'
        expect(dsl.to_target_string s).not.to.match /\\\\/

      it 'should not escape a single kind of quotes', ->
        s = new dsl.type.s '"'
        expect(dsl.to_target_string s).not.to.match /\\/
        s = new dsl.type.s "'"
        expect(dsl.to_target_string s).not.to.match /\\/
