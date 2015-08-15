// note that the node version of this function is defined in node.coffee
// hopefully just good enough html parsing
export function parse_document(html) {
  const doc = document.implementation.createHTMLDocument('');

  doc.body.innerHTML = html;
  return doc;
}
