define ->
  specs = [
    'core',
    'context',
    'notebook',
    'github',
    'graphite'
  ]

  require specs.map((s) -> "spec/#{s}.spec"), ->
    console.log 'loaded specs'
    require ['domReady!'], execJasmine

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
