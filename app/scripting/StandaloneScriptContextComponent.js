import React from 'react/addons';

import {createStandaloneScriptContext} from '../context';
import ComponentContextComponent from '../context/ComponentContextComponent';
import ContextAwareMixin from '../context/ContextAwareMixin';


export default React.createClass({
  mixins: [ContextAwareMixin],

  componentWillMount() {
    // FIXME #175 props can change
    this.scriptCtx = createStandaloneScriptContext(Object.assign({}, this.ctx(), this.props));
  },

  get_ctx() {
    return this.scriptCtx;
  },

  render() {
    return <ComponentContextComponent children={this.props.children} ctx={this.scriptCtx}/>;
  }
});
