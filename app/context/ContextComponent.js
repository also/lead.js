import React from 'react/addons';

import ContextRegisteringMixin from './ContextRegisteringMixin';
import ContextLayoutComponent from './ContextLayoutComponent';
import {isRunContext} from '.';


export default React.createClass({
  displayName: 'ContextComponent',

  mixins: [ContextRegisteringMixin],

  propTypes: {
    ctx(c) {
      if (!isRunContext(c.ctx)) {
        throw new Error('context required');
      }
    }
  },

  render() {
    return <ContextLayoutComponent ctx={this.props.ctx}/>;
  }
});
