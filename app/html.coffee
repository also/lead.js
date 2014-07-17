# note that the node version of this function is defined in node.coffee
# hopefully just good enough html parsing
exports.parse_document = (html) ->
  doc = document.implementation.createHTMLDocument ''
  doc.body.innerHTML = html
  doc
