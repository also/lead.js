jsdom = require 'jsdom'

exports.parse_document = (html) -> jsdom.jsdom html
