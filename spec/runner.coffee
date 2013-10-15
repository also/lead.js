define 'runner', (require) ->
  specs = [
    'notebook',
    'github',
  ]

  require specs.map((s) -> "spec/#{s}.spec"), ->
    console.log 'loaded specs'
    execJasmine()

  jasmineEnv = jasmine.getEnv()

  if window.configure_jasmine?
    window.configure_jasmine jasmineEnv
  else
    htmlReporter = new jasmine.HtmlReporter
    jasmineEnv.addReporter htmlReporter

    jasmineEnv.specFilter = (spec) ->
      htmlReporter.specFilter(spec)

  execJasmine = ->
    jasmineEnv.execute()
