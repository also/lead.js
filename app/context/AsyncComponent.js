import React from 'react/addons';

import ContextAwareMixin from './ContextAwareMixin';


const registerPromise = function (ctx, promise) {
  ctx.asyncs.push(1);
  promise.finally(() => {
    ctx.asyncs.push(-1);
    ctx.changes.push(true);
  });
};

export default React.createClass({
  mixins: [ContextAwareMixin],

  componentWillMount() {
    registerPromise(this.ctx(), this.props.promise);
  },

  componentWillUnmount() {
    // FIXME should unregister
  },

  render() {
    return <div>{this.props.children}</div>;
  }
});
