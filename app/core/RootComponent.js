import * as React from 'react';
import {Provider} from 'react-redux';

import ContextRegisteringMixin from '../context/ContextRegisteringMixin';


export default React.createClass({
  mixins: [ContextRegisteringMixin],

  childContextTypes: {
    app: React.PropTypes.object
  },

  getChildContext() {
    return {
      app: this.props.ctx
    };
  },

  render() {
    return (
      <Provider store={this.props.ctx.store}>
        {this.props.children}
      </Provider>
    );
  }
});
