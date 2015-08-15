import * as React from 'react/addons';

import {ExampleComponent} from '../builtins';


export default React.createClass({
  render() {
    const {docs} = this.props;
    return (
      <div className='graphite-sphinx-docs'>
        <div className='tip'>
          <code>{docs.signature}</code> is a Graphite function. The text below was extracted from the <a href='http://graphite.readthedocs.org/en/0.9.12/functions.html'>Graphite documentation</a>. Most Graphite functions are supported by the Lead server and lead.js DSL.
        </div>
        <div dangerouslySetInnerHTML={{__html: docs.docs}}/>
        {docs.examples.map((example, i) => <ExampleComponent value={`graph ${JSON.stringify(example)}`} run={true} key={i}/>)}
      </div>
    );
  }
});
