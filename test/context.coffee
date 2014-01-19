define (require) ->
  expect = require 'expect'
  context = require 'context'
  CoffeeScriptCell = require 'coffeescript_cell'

  eval_coffeescript_in_context = (run_context, string) ->
    context.run_in_context run_context, CoffeeScriptCell.create_fn string

  later = (done, fn) ->
    try
      fn()
      done()
    catch e
      done e

  describe 'contexts', ->
    describe 'base contexts', ->
      it 'can be created', (done) ->
        context.create_base_context(imports: ['builtins'])
        .then(-> done())
        .fail done

    describe 'run contexts', ->
      it 'can be created', ->
        context.create_run_context []

      it 'can output', ->
        run_context = context.create_run_context []
        html = 'hello, world'
        run_context.div html
        $el = context.render run_context
        expect($el.text()).to.be html

    describe 'full contexts', ->
      ctx = null
      complete_callback = null
      on_complete = (fn, done) ->
        complete_callback = ->
          later fn, done
      test_module =
        context_fns:
          test_function: fn: -> @value 'test value'
          complete: fn: -> complete_callback()
      result = null
      set_test_result = (r) ->
        result = r

      beforeEach (done) ->
        complete_callback = ->
        ctx = null
        result = null
        context.create_base_context(imports: ['builtins'])
        .then (base_context) ->
          base_context.modules.test_module = test_module
          ctx = context.create_context base_context
          ctx.imported_context_fns.complete = test_module.context_fns.complete
          done()
        .fail done # this won't actually get called: https://github.com/jrburke/requirejs/issues/911

      it 'can run javascript strings', ->
        run_context = context.create_run_context [ctx, {set_test_result}]
        context.eval_in_context run_context, 'this.set_test_result(1 + 1);'
        expect(result).to.be 2

      it 'can run coffeescript strings', ->
        run_context = context.create_run_context [ctx, {set_test_result}]
        eval_coffeescript_in_context run_context, '@set_test_result 1 + 1'
        expect(result).to.be 2

      it 'can eval functions', ->
        run_context = context.create_run_context [ctx, {set_test_result}]
        context.eval_in_context run_context, ->
          @set_test_result test_module.test_function()
        expect(result).to.be 'test value'

      it 'can run custom module functions', ->
        run_context = context.create_run_context [ctx, {set_test_result}]
        context.eval_in_context run_context, 'this.set_test_result(test_module.test_function())'
        expect(result).to.be 'test value'

      it 'can use other contexts', ->
        context_a = context.create_run_context [ctx]
        context_b = context.create_run_context [ctx, {context_a}]
        context.run_in_context context_a, ->
          @function_in_context_a = =>
            @value_in_context_a = 'a'
        eval_coffeescript_in_context context_b, "@value_in_context_b = @context_a.function_in_context_a()"
        expect(context_a.value_in_context_a).to.be 'a'
        expect(context_b.value_in_context_b).to.be 'a'

      it 'can use the running context', ->
        context_a = context.create_run_context [ctx]
        context_b = context.create_run_context [ctx, {context_a}]
        context.run_in_context context_a, ->
          @function_in_context_a = =>
            @in_running_context ->
              @value_in_context_a = 'a'
        eval_coffeescript_in_context context_b, "@value_in_context_b = @context_a.function_in_context_a()"
        expect(context_a.value_in_context_a).to.be(undefined)
        expect(context_b.value_in_context_a).to.be 'a'
        expect(context_b.value_in_context_b).to.be 'a'

      it 'can keep the running context in an async function', (done) ->
        context_a = context.create_run_context [ctx]
        context_b = context.create_run_context [ctx, {context_a}]
        context.run_in_context context_a, ->
          @function_in_context_a = =>
            @in_running_context ->
              @value_in_context_a = 'a'
        context.eval_in_context context_b, ->
          async = ->
            @value_in_context_b = @context_a.function_in_context_a()
            complete()
          setTimeout @keeping_context(async), 0
          null # https://github.com/also/lead.js/issues/94
        on_complete done, ->
          expect(context_a.value_in_context_a).to.be undefined
          expect(context_b.value_in_context_a).to.be 'a'
          expect(context_b.value_in_context_b).to.be 'a'

      it 'can use the running context when calling a function from another context', ->
        context_a = context.create_run_context [ctx]
        context_b = context.create_run_context [ctx, {context_a}]
        context.run_in_context context_a, ->
          @function_in_context_a = ->
              @value_in_context_a = 'a'
        context.eval_in_context context_b, ->
          @value_in_context_b = @in_running_context @context_a.function_in_context_a
        expect(context_a.value_in_context_a).to.be(undefined)
        expect(context_b.value_in_context_a).to.be 'a'
        expect(context_b.value_in_context_b).to.be 'a'

      it 'can output in nested items', ->
        context_a = context.create_run_context [ctx]
        context.eval_in_context context_a,->
          text 'a'
          @div ->
            text 'b'
        $el = context.render context_a
        expect($el.text()).to.be 'ab'

      it 'can render renderables', ->
        context_a = context.create_run_context [ctx]
        context.eval_in_context context_a,->
          text 'a'
          @add_renderable @renderable {}, ->
            $ '<p>b</p>'
        $el = context.render context_a
        expect($el.text()).to.be 'ab'

      it "doesn't allow output functions directly in renderables", ->
        context_a = context.create_run_context [ctx]
        context.eval_in_context context_a,->
          @add_renderable @renderable {}, ->
            text 'b'
        expect ->
          $el = context.render context_a
        .to.throwException (e) ->
          expect(e.message).to.be 'Output functions not allowed inside a renderable'

      it 'allows detached output functions in renderables', ->
        context_a = context.create_run_context [ctx]
        context.eval_in_context context_a,->
          text 'a'
          @add_renderable @renderable {}, ->
            @render @detached ->
              text 'b'
        $el = context.render context_a
        expect($el.text()).to.be 'ab'

      it 'supports renderable async', (done) ->
        context_a = context.create_run_context [ctx, {set_test_result}]
        context.eval_in_context context_a,->
          Q = require 'q'
          promise = Q true
          text 'a'
          @add_renderable @renderable promise, ->
            @render @detached -> @async ->
              $result = @div()
              promise.then =>
                $result.html '<p>b</p>'
                complete()
              promise
          text 'c'
        $el = context.render context_a
        expect($el.find('p').text()).to.be 'ac'
        on_complete done, ->
          expect($el.find('p').text()).to.be 'abc'

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

      it "allows output after render", (done) ->
        context_a = context.create_run_context [ctx, {set_test_result}]
        context.eval_in_context context_a, ->
          text 'a'
          setTimeout =>
            @text 'c'
            complete()
          , 0
          text 'b'
        $el = context.render context_a
        on_complete done, ->
          expect($el.text()).to.be 'abc'

      it 'allows output in an async block after render', (done) ->
        context_a = context.create_run_context [ctx, {set_test_result}]
        context.eval_in_context context_a, ->
          Q = require 'q'
          @async ->
            setTimeout @keeping_context ->
              @text 'a'
              complete()
            , 0
            Q true
          @text 'b'
        $el = context.render context_a
        on_complete done, ->
          expect($el.find('p').text()).to.be 'ab'
