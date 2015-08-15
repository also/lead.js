import jsdom from 'jsdom';


export function parse_document(html) {
  return jsdom.jsdom(html);
}
