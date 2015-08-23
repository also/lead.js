import * as React from 'react';

import * as Builder from '../builder';


export default React.createClass({
  displayName: 'BuilderAppComponent',
  render() {
    return <Builder.BuilderComponent root={this.props.query.root}/>;
  }
});
