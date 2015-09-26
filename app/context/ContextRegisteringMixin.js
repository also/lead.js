import {ctxsByRootNodeId} from './contextRegistry';
import ReactInstanceMap from 'react/lib/ReactInstanceMap';


export const ContextRegisteringMixin = {
  componentWillMount() {
    ctxsByRootNodeId[ReactInstanceMap.get(this)._rootNodeID] = this.props.ctx;
  },

  componentWillUnmount() {
    delete ctxsByRootNodeId[ReactInstanceMap.get(this)._rootNodeID];
  }
};
