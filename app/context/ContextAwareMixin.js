import ReactInstanceHandles from 'react/lib/ReactInstanceHandles';
import ReactInstanceMap from 'react/lib/ReactInstanceMap';
import _ from'underscore';

import {ctxsByRootNodeId} from './contextRegistry';


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

export default {
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
