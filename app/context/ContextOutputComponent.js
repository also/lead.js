import React from 'react/addons';

import ContextAwareMixin from './ContextAwareMixin';
import ContextLayoutComponent from './ContextLayoutComponent';


export default React.createClass({
  displayName: 'ContextOutputComponent',

  mixins: [ContextAwareMixin],

  render() {
    return <ContextLayoutComponent ctx={this.ctx()}/>;
  }
});
