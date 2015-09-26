import React from 'react/addons';

import ContextRegisteringMixin from './ContextRegisteringMixin';


export default React.createClass({
  displayName: 'ComponentContextComponent',

  mixins: [ContextRegisteringMixin],

  render() {
    return <div>{this.props.children}</div>;
  }
});
