expect = require 'expect.js'
Context = require '../app/context'
CoffeeScriptCell = require '../app/coffeescript_cell'
React = require 'react'
$ = require 'jquery'

require('../app/modules').init_modules([])

eval_coffeescript_in_context = (run_context, string) ->
  Context.run_in_context run_context, CoffeeScriptCell.create_fn string

render = (context) ->
  $result = $ '<div/>'
  # FIXME renderComponentToString doesn't work for the output after render tests
  React.renderComponent context.component, $result.get(0)
  $result


later = (done, fn) ->
  try
    fn()
    done()
  catch e
    done e

describe 'contexts', ->
  describe 'base contexts', ->
    it 'can be created', ->
      Context.create_base_context()

  describe 'run contexts', ->
    context = null
    beforeEach ->
      base_context = Context.create_base_context()
      context = Context.create_context(base_context)

    it 'can be created', ->
      Context.create_run_context [context]

    it 'can output', ->
      run_context = Context.create_run_context [context]
      text = 'hello, world'
      Context.add_component run_context, React.DOM.span null, text
      $el = render run_context
      expect($el.text()).to.be text

  describe 'full contexts', ->
    ctx = null
    complete_callback = null
    on_complete = (fn, done) ->
      complete_callback = ->
        later fn, done
    test_module =
      context_fns:
        test_function: fn: -> Context.value 'test value'
        complete: fn: -> complete_callback()
    result = null
    set_test_result = (r) ->
      result = r

    beforeEach ->
      complete_callback = ->
      ctx = null
      result = null
      base_context = Context.create_base_context(imports: ['builtins.*'])
      base_context.modules.test_module = test_module
      base_context.imports.push 'test_module.*'
      ctx = Context.create_context base_context

    it 'can run javascript strings', ->
      run_context = Context.create_run_context [ctx, {set_test_result}]
      Context.eval_in_context run_context, 'this.set_test_result(1 + 1);'
      expect(result).to.be 2

    it 'can run coffeescript strings', ->
      run_context = Context.create_run_context [ctx, {set_test_result}]
      eval_coffeescript_in_context run_context, '@set_test_result 1 + 1'
      expect(result).to.be 2

    it 'can eval functions', ->
      run_context = Context.create_run_context [ctx, {set_test_result}]
      Context.eval_in_context run_context, ->
        @set_test_result test_module.test_function()
      expect(result).to.be 'test value'

    it 'can run custom module functions', ->
      run_context = Context.create_run_context [ctx, {set_test_result}]
      Context.eval_in_context run_context, 'this.set_test_result(test_module.test_function())'
      expect(result).to.be 'test value'

    it 'can use other contexts', ->
      context_a = Context.create_run_context [ctx]
      context_b = Context.create_run_context [ctx, {context_a}]
      Context.run_in_context context_a, (ctx) ->
        ctx.function_in_context_a = ->
          ctx.value_in_context_a = 'a'
      eval_coffeescript_in_context context_b, "@value_in_context_b = @context_a.function_in_context_a()"
      expect(context_a.value_in_context_a).to.be 'a'
      expect(context_b.value_in_context_b).to.be 'a'

    it 'can use the running context', ->
      context_a = Context.create_run_context [ctx]
      context_b = Context.create_run_context [ctx, {context_a}]
      Context.run_in_context context_a, (ctx) ->
        ctx.function_in_context_a = ->
          Context.in_running_context ctx, (ctx) ->
            ctx.value_in_context_a = 'a'
      eval_coffeescript_in_context context_b, "@value_in_context_b = @context_a.function_in_context_a()"
      expect(context_a.value_in_context_a).to.be(undefined)
      expect(context_b.value_in_context_a).to.be 'a'
      expect(context_b.value_in_context_b).to.be 'a'

    it 'can keep the running context in an async function', (done) ->
      context_a = Context.create_run_context [ctx]
      context_b = Context.create_run_context [ctx, {context_a}]
      context_b.scope.Context = Context
      Context.run_in_context context_a, (ctx) ->
        ctx.function_in_context_a = ->
          Context.in_running_context ctx, (ctx) ->
            ctx.value_in_context_a = 'a'
      Context.eval_in_context context_b, ->
        async = (ctx) ->
          ctx.value_in_context_b = ctx.context_a.function_in_context_a()
          complete()
        setTimeout Context.keeping_context(@, async), 0
      on_complete done, ->
        expect(context_a.value_in_context_a).to.be undefined
        expect(context_b.value_in_context_a).to.be 'a'
        expect(context_b.value_in_context_b).to.be 'a'

    it 'can use the running context when calling a function from another context', ->
      context_a = Context.create_run_context [ctx]
      context_b = Context.create_run_context [ctx, {context_a}]
      context_b.scope.Context = Context

      Context.run_in_context context_a, (ctx) ->
        ctx.function_in_context_a = ->
          Context.in_running_context ctx, (ctx) ->
            ctx.value_in_context_a = 'a'
      Context.eval_in_context context_b, ->
        @value_in_context_b = @context_a.function_in_context_a()
      expect(context_a.value_in_context_a).to.be(undefined)
      expect(context_b.value_in_context_a).to.be 'a'
      expect(context_b.value_in_context_b).to.be 'a'

    it 'can output in nested items', ->
      context_a = Context.create_run_context [ctx]
      context_a.scope.Context = Context
      Context.eval_in_context context_a, ->
        text 'a'
        Context.nested_item @, ->
          text 'b'
      $el = render context_a
      expect($el.text()).to.be 'ab'

    it "allows output after render", (done) ->
      context_a = Context.create_run_context [ctx, {set_test_result}]
      context_a.scope.Context = Context
      Context.eval_in_context context_a, ->
        text 'a'
        setTimeout Context.keeping_context @, ->
          text 'c'
          complete()
        , 0
        text 'b'
      $el = render context_a
      on_complete done, ->
        expect($el.text()).to.be 'abc'

    it 'allows output in an async block after render', (done) ->
      context_a = Context.create_run_context [ctx, {set_test_result}]
      context_a.scope.Context = Context
      Context.eval_in_context context_a, ->
        Context.nested_item @, (ctx) ->
          setTimeout Context.keeping_context ctx, ->
            text 'a'
            complete()
          , 0
        text 'b'
      $el = render context_a
      on_complete done, ->
        expect($el.find('p').text()).to.be 'ab'
