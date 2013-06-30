ready = false

# FIXME
window.testing = true

specs = [
  'core',
  'context',
  'notebook',
  'github',
  'graphite'
]

loaded = ->
  if ready
    execJasmine()
  ready = true

window.require =
  callback: ->
    requirejs specs.map((s) -> "spec/#{s}.spec"), ->
      console.log 'loaded specs'
      loaded()

jasmineEnv = jasmine.getEnv()

if window.configure_jasmine?
  window.configure_jasmine jasmineEnv
else
  htmlReporter = new jasmine.HtmlReporter
  jasmineEnv.addReporter htmlReporter

  jasmineEnv.specFilter = (spec) ->
    htmlReporter.specFilter(spec)

window.onload = ->
  loaded()

execJasmine = ->
  jasmineEnv.execute()
  console.log 'ran jasmine'