import ReactInstanceMap from 'react/lib/ReactInstanceMap';

import {ctxsByRootNodeId} from './contextRegistry';


export default {
  componentWillMount() {
    ctxsByRootNodeId[ReactInstanceMap.get(this)._rootNodeID] = this.props.ctx;
  },

  componentWillUnmount() {
    delete ctxsByRootNodeId[ReactInstanceMap.get(this)._rootNodeID];
  }
};
