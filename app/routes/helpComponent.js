import * as React from 'react';
import {Navigation} from 'react-router';

import HelpPageComponent from '../HelpPageComponent';
import StandaloneScriptContextComponent from '../scripting/StandaloneScriptContextComponent';
import {encodeNotebookValue} from '../notebook';


export default React.createClass({
  mixins: [Navigation],

  runScript(value) {
    return this.transitionTo('raw_notebook', {
      splat: encodeNotebookValue(value)
    });
  },

  navigate(key) {
    return this.transitionTo('help', {
      docKey: key
    });
  },

  render() {
    return (
      <div className='help output'>
        <StandaloneScriptContextComponent {...{
          runScript: this.runScript,
          docsNavigate: this.navigate
        }}>
          <HelpPageComponent doc_key={this.props.params.docKey}/>
        </StandaloneScriptContextComponent>
      </div>
    );
  }
});
