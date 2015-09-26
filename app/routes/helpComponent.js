import * as React from 'react';
import {Navigation} from 'react-router';

import HelpPageComponent from '../HelpPageComponent';
import TopLevelContextComponent from '../context/TopLevelContextComponent';
import AppAwareMixin from '../AppAwareMixin';
import {encodeNotebookValue} from '../notebook';


export default React.createClass({
  mixins: [Navigation, AppAwareMixin],

  run(value) {
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
    const {imports, modules} = this.context.app;

    return (
      <div className='help output'>
        <TopLevelContextComponent {...{imports, modules}} context={{
          app: this.context.app,
          run: this.run,
          docsNavigate: this.navigate
        }}>
          <HelpPageComponent doc_key={this.props.params.docKey}/>
        </TopLevelContextComponent>
      </div>
    );
  }
});
