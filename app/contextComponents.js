import React from 'react/addons';
import ReactInstanceHandles from 'react/lib/ReactInstanceHandles';
import _ from'underscore';


const contextsByRootNodeId = {};

function findAncestorContexts(componentInstance) {
  const result = [];

  _.each(ReactInstanceHandles.traverseAncestors(componentInstance._rootNodeID, (id) => {
    const context = contextsByRootNodeId[id];
    if (context) {
      result.unshift(context);
    }
  }));

  return result;
}

export const ContextRegisteringMixin = {
  componentWillMount() {
    contextsByRootNodeId[this._rootNodeID] = this.props.ctx;
  },

  componentWillUnmount() {
    delete contextsByRootNodeId[this._rootNodeID];
  }
};

export const ContextAwareMixin = {
  getInitialState() {
    // TODO update later in lifecycle
    return {
      ctx: this.ctx()
    };
  },

  _getCtx() {
    return findAncestorContexts(this)[0];
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
