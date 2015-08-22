import React from 'react/addons';
import ReactInstanceHandles from 'react/lib/ReactInstanceHandles';
import ReactInstanceMap from 'react/lib/ReactInstanceMap';
import _ from'underscore';


const ctxsByRootNodeId = {};

function findAncestorCtxs(_rootNodeID) {
  const result = [];

  _.each(ReactInstanceHandles.traverseAncestors(_rootNodeID, (id) => {
    const context = ctxsByRootNodeId[id];
    if (context) {
      result.unshift(context);
    }
  }));

  return result;
}

export const ContextRegisteringMixin = {
  componentWillMount() {
    ctxsByRootNodeId[ReactInstanceMap.get(this)._rootNodeID] = this.props.ctx;
  },

  componentWillUnmount() {
    delete ctxsByRootNodeId[ReactInstanceMap.get(this)._rootNodeID];
  }
};

export const ContextAwareMixin = {
  _getCtx() {
    return findAncestorCtxs(ReactInstanceMap.get(this)._rootNodeID)[0];
  },

  ctx() {
    if (!this._ctx) {
      this._ctx = this._getCtx();
    }
    return this._ctx;
  }
};

export const ComponentContextComponent = React.createClass({
  displayName: 'ComponentContextComponent',

  mixins: [ContextRegisteringMixin],

  render() {
    return <div>{this.props.children}</div>;
  }
});
