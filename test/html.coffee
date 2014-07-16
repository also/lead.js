expect = require 'expect.js'
Html = require '../html'

it 'parses html', ->
  doc = Html.parse_document '<html><body><div id="test">test</div></body></html>'
  expect(doc.querySelector('#test').id).to.be 'test'
