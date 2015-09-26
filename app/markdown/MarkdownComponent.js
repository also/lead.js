import React from 'react/addons';
import URI from 'urijs';
import Marked from 'marked';

import UserHtmlComponent from './UserHtmlComponent';


function fix_marked_renderer_href(fn, baseHref) {
  return (href, ...args) => fn.call(this, new URI(href).absoluteTo(baseHref).toString(), ...args);
}

export default React.createClass({
  render() {
    const {opts={}} = this.props;
    const markedOpts = {};
    const {base_href} = opts;

    if (base_href != null) {
      const renderer = new Marked.Renderer();

      renderer.link = fix_marked_renderer_href(renderer.link, base_href);
      renderer.image = fix_marked_renderer_href(renderer.image, base_href);
      markedOpts.renderer = renderer;
    }

    const html = Marked(this.props.value, markedOpts);

    return <UserHtmlComponent html={html}/>
  }
});
