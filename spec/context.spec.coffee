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

      it 'can eval functions', ->
        run_context = context.create_run_context [ctx, {set_test_result}]
        context.eval_in_context run_context, ->
          @set_test_result test_module.test_function()
        expect(result).toBe 'test value'

      it 'can run custom module functions', ->
        run_context = context.create_run_context [ctx, {set_test_result}]
        context.eval_in_context run_context, 'this.set_test_result(test_module.test_function())'
        expect(result).toBe 'test value'

      it 'can use other contexts', ->
        context_a = context.create_run_context [ctx]
        context_b = context.create_run_context [ctx, {context_a}]
        context.run_in_context context_a, ->
          @function_in_context_a = =>
            @value_in_context_a = 'a'
        context.eval_coffeescript_in_context context_b, "@value_in_context_b = @context_a.function_in_context_a()"
        expect(context_a.value_in_context_a).toBe 'a'
        expect(context_b.value_in_context_b).toBe 'a'

      it 'can use the running context', ->
        context_a = context.create_run_context [ctx]
        context_b = context.create_run_context [ctx, {context_a}]
        context.run_in_context context_a, ->
          @function_in_context_a = =>
            @in_running_context ->
              @value_in_context_a = 'a'
        context.eval_coffeescript_in_context context_b, "@value_in_context_b = @context_a.function_in_context_a()"
        expect(context_a.value_in_context_a).toBeUndefined()
        expect(context_b.value_in_context_a).toBe 'a'
        expect(context_b.value_in_context_b).toBe 'a'

      it 'can keep the running context in an async function', ->
        context_a = context.create_run_context [ctx]
        context_b = context.create_run_context [ctx, {context_a}]
        context.run_in_context context_a, ->
          @function_in_context_a = =>
            @in_running_context ->
              @value_in_context_a = 'a'
        context.eval_in_context context_b, ->
          async = ->
            @value_in_context_b = @context_a.function_in_context_a()
          setTimeout @keeping_context(async), 0
        waitsFor (-> context_b.value_in_context_b?), 1000
        runs ->
          expect(context_a.value_in_context_a).toBeUndefined()
          expect(context_b.value_in_context_a).toBe 'a'
          expect(context_b.value_in_context_b).toBe 'a'

      it 'can use the running context when calling a function from another context', ->
        context_a = context.create_run_context [ctx]
        context_b = context.create_run_context [ctx, {context_a}]
        context.run_in_context context_a, ->
          @function_in_context_a = ->
              @value_in_context_a = 'a'
        context.eval_in_context context_b, ->
          @value_in_context_b = @in_running_context @context_a.function_in_context_a
        expect(context_a.value_in_context_a).toBeUndefined()
        expect(context_b.value_in_context_a).toBe 'a'
        expect(context_b.value_in_context_b).toBe 'a'

      it 'can output in nested items', ->
        context_a = context.create_run_context [ctx]
        context.eval_in_context context_a,->
          text 'a'
          @nested 'nest', ->
            text 'b'
        $el = context.render context_a
        expect($el.text()).toBe 'ab'

      it 'can render renderables', ->
        context_a = context.create_run_context [ctx]
        context.eval_in_context context_a,->
          text 'a'
          @add_renderable @renderable {}, ->
            $ '<p>b</p>'
        $el = context.render context_a
        expect($el.text()).toBe 'ab'

      it "doesn't allow output functions directly in renderables", ->
        context_a = context.create_run_context [ctx]
        context.eval_in_context context_a,->
          @add_renderable @renderable {}, ->
            text 'b'
        expect ->
          $el = context.render context_a
        .toThrow new Error 'Output functions not allowed inside a renderable'

      it 'allows detached output functions in renderables', ->
        context_a = context.create_run_context [ctx]
        context.eval_in_context context_a,->
          text 'a'
          @add_renderable @renderable {}, ->
            @render @detached ->
              text 'b'
        $el = context.render context_a
        expect($el.text()).toBe 'ab'

      it 'supports renderable async', ->
        context_a = context.create_run_context [ctx, {set_test_result}]
        context.eval_in_context context_a,->
          Q = require 'q'
          promise = Q true
          text 'a'
          @add_renderable @renderable promise, ->
            @render @detached -> @async ->
              $result = @div()
              promise.then =>
                $result.text 'b'
                @set_test_result true
              promise
          text 'c'
        $el = context.render context_a
        expect($el.text()).toBe 'ac'
        waitsFor (-> result), 1000
        runs ->
          expect($el.text()).toBe 'abc'

      # TODO reconsider this behavior
      ###
      it "doesn't allow output after render", ->
        context_a = context.create_run_context [ctx, {set_test_result}]
        context.eval_in_context context_a, ->
          setTimeout =>
            expect =>
              @text 'a'
            .toThrow new Error 'already rendered'
            @set_test_result true
          , 0
        $el = context.render context_a
        waitsFor (-> result), 1000
      ###

      it "allows output after render", ->
        context_a = context.create_run_context [ctx, {set_test_result}]
        context.eval_in_context context_a, ->
          text 'a'
          setTimeout =>
            @text 'c'
            @set_test_result true
          , 0
          text 'b'
        $el = context.render context_a
        waitsFor (-> result), 1000
        runs ->
          expect($el.text()).toBe 'abc'

      it 'allows output in an async block after render', ->
        context_a = context.create_run_context [ctx, {set_test_result}]
        context.eval_in_context context_a, ->
          Q = require 'q'
          @async ->
            setTimeout @keeping_context ->
              @text 'a'
              @set_test_result true
            , 0
            Q true
          @text 'b'
        $el = context.render context_a
        waitsFor (-> result), 1000
        runs ->
          expect($el.text()).toBe 'ab'
