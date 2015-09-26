import React from 'react/addons';

import ContextRegisteringMixin from './ContextRegisteringMixin';


export const ComponentContextComponent = React.createClass({
  displayName: 'ComponentContextComponent',

  mixins: [ContextRegisteringMixin],

  render() {
    return <div>{this.props.children}</div>;
  }
});
