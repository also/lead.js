import * as React from 'react';
import {Navigation} from 'react-router';

import HelpPageComponent from '../helpPageComponent';
import {TopLevelContextComponent} from '../context';
import AppAwareMixin from '../appAwareMixin';
import {encodeNotebookValue} from '../notebook';


export default React.createClass({
  displayName: 'HelpComponent',
  mixins: [Navigation, AppAwareMixin],
  run(value) {
    return this.transitionTo('raw_notebook', {
      splat: encodeNotebookValue(value)
    });
  },
  navigate(key) {
    return this.transitionTo('help', {
      key: key
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
          <HelpPageComponent doc_key={this.props.params.key}/>
        </TopLevelContextComponent>
      </div>
    );
  }
});
