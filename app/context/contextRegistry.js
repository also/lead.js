import ReactInstanceMap from 'react/lib/ReactInstanceMap';


export const ctxsByRootNodeId = {};

export function register(element, ctx) {
  ctxsByRootNodeId[ReactInstanceMap.get(element)._rootNodeID] = ctx;
}

export function unregister(element) {
  delete ctxsByRootNodeId[ReactInstanceMap.get(element)._rootNodeID];
}
