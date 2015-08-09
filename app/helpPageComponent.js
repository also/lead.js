import * as React from 'react';

import {ContextAwareMixin} from './contextComponents';
import * as Documentation from './documentation';
import NotFoundComponent from './routes/notFoundComponent';


const HelpPathComponent = React.createClass({
  displayName: 'HelpPathComponent',
  render() {
    const path = Documentation.keyToPath(this.props.doc_key);

    const paths = [];
    for (let i = 0; i < path.length; i++) {
      paths.push({
        path: path.slice(0, i + 1),
        segment: path[i]
      });
    }

    return (
      <div className='help-path'>
        <Documentation.DocumentationLinkComponent key='main'>help</Documentation.DocumentationLinkComponent>
        {paths.map(({path, segment}, i) => (
          <span key={i}>
            {' '}
            <i className='fa fa-caret-right'/>
            {' '}
            <Documentation.DocumentationLinkComponent key={path}>
              {Documentation.keyToString(segment)}
            </Documentation.DocumentationLinkComponent>
          </span>
        ))}
      </div>
    );
  }
});

export default React.createClass({
  displayName: 'HelpWrapperComponent',
  mixins: [ContextAwareMixin],
  render() {
    const resolvedKey = Documentation.getKey(this.state.ctx, this.props.doc_key);

    if (resolvedKey) {
      const doc = Documentation.getDocumentation(resolvedKey);

      return (
        <div>
          <HelpPathComponent doc_key={resolvedKey}/>
          <Documentation.DocumentationItemComponent ctx={this.state.ctx} doc={doc}/>
        </div>
      );
    } else {
      return <NotFoundComponent/>;
    }
  }
});
