import * as React from 'react/addons';

import {TreeNodeComponent} from '../tree';


export default React.createClass({
  render() {
    const {node} = this.props;

    return <TreeNodeComponent {...this.props}>{node.path === '' ? 'All Metrics' : node.name}</TreeNodeComponent>;
  }
});
