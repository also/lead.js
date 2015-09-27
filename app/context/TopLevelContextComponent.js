import React from 'react/addons';

import {createStandaloneScriptContext} from './';
import ComponentContextComponent from './ComponentContextComponent';


export default React.createClass({
  displayName: 'TopLevelContextComponent',

  getInitialState() {
    // FIXME #175 props can change
    const ctx = createStandaloneScriptContext(this.props);
    return {ctx};
  },

  get_ctx() {
    return this.state.ctx;
  },

  render() {
    return <ComponentContextComponent children={this.props.children} ctx={this.state.ctx}/>;
  }
});
