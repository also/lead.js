import * as React from 'react/addons';

import ContextAwareMixin from '../context/ContextAwareMixin';
import * as Server from '../server';
import {TreeComponent} from '../tree';

import MetricTreeNodeComponent from './MetricTreeNodeComponent';
import MetricTreeErrorComponent from './MetricTreeErrorComponent';


export default React.createClass({
  mixins: [ContextAwareMixin],

  leafClicked(path) {
    const {leafClicked} = this.props;
    if (leafClicked) {
      leafClicked(path);
    } else {
      this.ctx().runScript(`q(${JSON.stringify(path)})`);
    }
  },

  loadChildren(path) {
    const subpath = path === '' ? '*' : `${path}.*`;
    return Server.find(this.ctx(), subpath).then(({result}) => {
      return result.map(({path, is_leaf}) => {
        const parts = path.split('.');
        const name = parts[parts.length - 1];

        return {
          path: path,
          isLeaf: is_leaf,
          name: name
        };
      });
    });
  },

  render() {
    let root;

    if (this.props.root) {
      root = {
        path: this.props.root,
        isLeaf: false,
        name: this.props.root
      };
    } else {
      root = {
        path: '',
        isLeaf: false,
        name: 'root'
      };
    }

    return <TreeComponent
      root={root}
      leafClicked={this.leafClicked}
      loadChildren={this.loadChildren}
      nodeClass={MetricTreeNodeComponent}
      errorNodeClass={MetricTreeErrorComponent}/>;
  }
});
