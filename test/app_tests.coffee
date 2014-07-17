_ = require 'underscore'
expect = require 'expect.js'
wd = require 'wd'

do_then = (promise, thens...) ->
  _.reduce thens, ((p, t) -> p.then t), promise

SHIFT_ENTER = wd.SPECIAL_KEYS.Shift + wd.SPECIAL_KEYS.Return + wd.SPECIAL_KEYS.NULL
command_key = (browser) ->
  if browser.capabilities.platform == 'MAC' or browser.capabilities.platform == 'Mac OS X'
    wd.SPECIAL_KEYS.Command
  else
    wd.SPECIAL_KEYS.Control
select_all = (browser) -> command_key(browser) + 'a' + wd.SPECIAL_KEYS.NULL

# Shift Return doesn't work in Internet Explorer
# Command a doesn't work in Firefox on OS X
# Safari doesn't support interactivity https://code.google.com/p/selenium/issues/detail?id=4136

module.exports = (browser) ->
  # TODO .text() on input and output cells gives different whitespace
  # in different browsers
  do_then(
    browser
      .get('http://localhost:8000/dist/index.html')
      .setImplicitWaitTimeout(10000)
    -> browser.title()
    (title) -> expect(title).to.be 'lead.js'

    -> browser.elementByCss('.input[data-cell-number="1"] .code').text()
    (code) -> expect(code).to.be("help 'introduction'")

    -> browser.elementByCss('.input:not([data-cell-number]) .code').text()
    (code) -> expect(code.trim()).to.be ''

    -> browser.keys '1+1'
    # TODO wait for text in input cell, not everywhere
    -> browser.waitFor(wd.asserters.textInclude('1+1'))
    -> browser.elementByCss('.input:not([data-cell-number]) .code').text()
    (code) -> expect(code.trim()).to.be '1+1'

    -> browser.keys SHIFT_ENTER
    -> browser.elementByCss('.output[data-cell-number="2"]').text()
    (result) -> expect(result.trim()).to.be '2'

    -> browser.elementByCss('.input[data-cell-number="1"] .CodeMirror-scroll').click()
    -> browser.keys select_all browser
    -> browser.keys wd.SPECIAL_KEYS['Back space']
    -> browser.keys '2+2'
    -> browser.keys SHIFT_ENTER
    -> browser.elementByCss('.input[data-cell-number="3"] .code').text()
    (code) -> expect(code.trim()).to.be '2+2'

    -> browser.elementByCss('.output[data-cell-number="3"]').text()
    (result) -> expect(result.trim()).to.be '4'
  )
