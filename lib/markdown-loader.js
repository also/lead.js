import Marked from 'marked';
import _ from 'underscore';


export default function (content) {
  this.cacheable();

  const images = [];
  const renderer = new Marked.Renderer();
  renderer.image = (i) => {
    const req = JSON.stringify(`file?name=images/[name]-[hash].[ext]!./${i}`);
    images.push(`${JSON.stringify(i)}: require(${req})`);
  }
  Marked(content, {renderer});
  return `module.exports = {\n  content: ${JSON.stringify(content)},\n  images: {\n    ${images.join(',\n    ')}}};`
}
