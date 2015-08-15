import * as React from 'react/addons';

import {DocumentationLinkComponent} from '../documentation';


export default React.createClass({
  render() {
    return (
      <div className='graphite-sphinx-docs'>
        <div className='tip'>
          This is a Graphite parameter. The text below was extracted from the <a href='http://graphite.readthedocs.org/en/0.9.12/functions.html'>Graphite documentation</a>. Some Graphite parameters are supported by the <DocumentationLinkComponent key='graphing.graph'><code>graph</code></DocumentationLinkComponent> function.
        </div>
        <div ref='docs'/>
      </div>
    );
  },

  componentDidMount() {
    const {ctx, docs} = this.props;

    // TODO
    const div = this.refs.docs.getDOMNode();
    div.insertAdjacentHTML('beforeend', docs);
    div.querySelectorAll('a').forEach(a => a.onclick = e => {
      e.preventDefault();
      const href = a.getAttribute('href');
      if (href[0] === '#') {
        ctx.run(`help 'server.parameters.${decodeURI(href.substr(1))}'`);
      }
    });
  }
});
