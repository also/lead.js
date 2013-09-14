define (require) ->
  context = require 'context'

  describe 'contexts', ->
    describe 'base contexts', ->
      it 'can be created', ->
        created = false
        context.create_base_context(imports: ['builtins'])
        .then ->
          created = true
        waitsFor (-> created), 1000

    describe 'run contexts', ->
      it 'can be created', ->
        context.create_run_context []

      it 'can output', ->
        run_context = context.create_run_context []
        html = 'hello, world'
        run_context.output html
        $el = context.render run_context
        expect($el.text()).toBe html

    describe 'full contexts', ->
      ctx = null
      test_module =
        context_fns:
          test_function: fn: -> @value 'test value'
      result = null
      set_test_result = (r) ->
        result = r
      beforeEach ->
        ctx = null
        result = null
        success = null
        context.create_base_context(imports: ['builtins'])
        .then (base_context) ->
          base_context.modules.test_module = test_module
          ctx = context.create_context base_context
          success = true
        waitsFor (-> success), 1000

      it 'can run javascript strings', ->
        run_context = context.create_run_context [ctx, {set_test_result}]
        context.eval_in_context run_context, 'this.set_test_result(1 + 1);'
        expect(result).toBe 2

      it 'can run coffeescript strings', ->
        run_context = context.create_run_context [ctx, {set_test_result}]
        context.eval_coffeescript_in_context run_context, '@set_test_result 1 + 1'
        expect(result).toBe 2

      it 'can run custom module functions', ->
        run_context = context.create_run_context [ctx, {set_test_result}]
        context.eval_in_context run_context, 'this.set_test_result(test_module.test_function())'
        expect(result).toBe 'test value'
