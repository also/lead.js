import React from 'react';
import _ from 'underscore';


const NodePropType = React.PropTypes.shape({
  path: React.PropTypes.string.isRequired,
  name: React.PropTypes.string.isRequired,
  isLeaf: React.PropTypes.bool.isRequired
});

const TreeNodeComponent = React.createClass({
  contextTypes: {
    nodeClass: React.PropTypes.func.isRequired,
    errorNodeClass: React.PropTypes.func.isRequired,
    tree_state: React.PropTypes.object.isRequired,
    value: React.PropTypes.func.isRequired,
    toggle: React.PropTypes.func.isRequired,
    leafClicked: React.PropTypes.func.isRequired
  },

  propTypes: {
    node: NodePropType.isRequired
  },

  render() {
    const {node, children} = this.props;
    const {nodeClass: NodeClass, errorNodeClass: ErrorNodeClass} = this.context;
    const {path} = node;
    const state = this.context.tree_state[path];

    let child;

    if (state === 'open') {
      const sortedNodes = _.sortBy(this.context.value(path), (child) => child.name);
      const child_nodes = sortedNodes.map((child) => <NodeClass node={child}/>);

      child = <ul>{child_nodes}</ul>;
    } else if (state === 'failed') {
      child = <ErrorNodeClass {... this.props}/>;
    } else {
      child = null;
    }

    let toggle;

    if (node.isLeaf) {
      toggle = 'fa fa-fw';
    } else if (state === 'open' || state === 'failed') {
      toggle = 'fa fa-fw fa-caret-down';
    } else if (state === 'opening') {
      toggle = 'fa fa-fw fa-spinner fa-spin';
    } else {
      toggle = 'fa fa-fw fa-caret-right'
    }

    return (
      <li>
        <span onClick={this.handleClick}>
          <i className={toggle}/>
          {children}
        </span>
        <div className='child'>{child}</div>
      </li>
    );
  },

  handleClick() {
    const path = this.props.node.path;

    if (this.props.node.isLeaf) {
      this.context.leafClicked(path);
    } else {
      this.context.toggle(path)
    }
  }
});

const TreeComponent = React.createClass({
  propTypes: {
    root: NodePropType,
    leafClicked: React.PropTypes.func.isRequired,
    loadChildren: React.PropTypes.func.isRequired,
    nodeClass: React.PropTypes.func.isRequired,
    errorNodeClass: React.PropTypes.func.isRequired
  },

  childContextTypes: {
    nodeClass: React.PropTypes.func.isRequired,
    errorNodeClass: React.PropTypes.func.isRequired,
    tree_state: React.PropTypes.object.isRequired,
    value: React.PropTypes.func.isRequired,
    toggle: React.PropTypes.func.isRequired,
    leafClicked: React.PropTypes.func.isRequired
  },

  getDefaultProps() {
    return {root: ''};
  },

  getInitialState() {
    return {
      cache: {},
      tree_state: {}
    }
  },

  toggle(path) {
    const state = this.state.tree_state[path];
    if (state === 'closed' || state == null) {
      this.open(path);
    } else {
      this.close(path);
    }
  },

  value(path) {
    const {cache} = this.state
    return cache[path] ? cache[path].inspect().value : null;
  },

  open(path) {
    const tree_state = _.clone(this.state.tree_state);
    const cache = _.clone(this.state.cache);

    const state = this.state.cache[path];
    if (state && state.isFulfilled()) {
      tree_state[path] = 'open';
    } else {
      tree_state[path] = 'opening';

      if (!state || state.isRejected()) {
        const promise = this.props.loadChildren(path);
        cache[path] = promise;
        promise.then(
          () => {
            if (this.state.cache[path] === promise) {
              const tree_state = _.clone(this.state.tree_state);
              tree_state[path] = 'open';
              this.setState({tree_state});
            }
          },
          () => {
            if (this.state.cache[path] === promise) {
              const tree_state = _.clone(this.state.tree_state);
              tree_state[path] = 'failed';
              this.setState({tree_state});
            }
          }
        );
      }
    }

    this.setState({tree_state, cache});
  },

  close(path) {
    const tree_state = _.clone(this.state.tree_state);
    tree_state[path] = 'closed';
    const cache = this.state.cache;
    if (cache[path] && cache[path].isRejected()) {
      const cache = _.clone(cache);
      delete cache[path];
    }
    this.setState({tree_state, cache});
  },

  componentWillMount() {
    this.open(this.props.root);
  },

  getChildContext() {
    return {
      tree_state: this.state.tree_state,
      nodeClass: this.props.nodeClass,
      errorNodeClass: this.props.errorNodeClass,
      value: this.value,
      toggle: this.toggle,
      leafClicked: this.props.leafClicked
    };
  },

  render() {
    const {nodeClass: NodeClass} = this.props;
    return <ul className='simple-tree'><NodeClass node={this.props.root}/></ul>;
  }
});

export {TreeNodeComponent, TreeComponent};
