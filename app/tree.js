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
    treeState: React.PropTypes.object.isRequired,
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
    const state = this.context.treeState[path];

    let child;

    if (state === 'open') {
      const sortedNodes = _.sortBy(this.context.value(path), (child) => child.name);
      const childNodes = sortedNodes.map((child) => <NodeClass node={child}/>);

      child = <ul>{childNodes}</ul>;
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
      toggle = 'fa fa-fw fa-caret-right';
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
      this.context.toggle(path);
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
    treeState: React.PropTypes.object.isRequired,
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
      treeState: {}
    };
  },

  toggle(path) {
    const state = this.state.treeState[path];
    if (state === 'closed' || state == null) {
      this.open(path);
    } else {
      this.close(path);
    }
  },

  value(path) {
    const {cache} = this.state;
    return cache[path] ? cache[path].inspect().value : null;
  },

  open(path) {
    const treeState = Object.assign({}, this.state.treeState);
    const cache = Object.assign({}, this.state.cache);

    const state = this.state.cache[path];
    if (state && state.isFulfilled()) {
      treeState[path] = 'open';
    } else {
      treeState[path] = 'opening';

      if (!state || state.isRejected()) {
        const promise = this.props.loadChildren(path);
        cache[path] = promise;
        promise.then(
          () => {
            if (this.state.cache[path] === promise) {
              const treeState = Object.assign({}, this.state.treeState);
              treeState[path] = 'open';
              this.setState({treeState});
            }
          },
          () => {
            if (this.state.cache[path] === promise) {
              const treeState = Object.assign({}, this.state.treeState);
              treeState[path] = 'failed';
              this.setState({treeState});
            }
          }
        );
      }
    }

    this.setState({treeState, cache});
  },

  close(path) {
    const treeState = Object.assign({}, this.state.treeState);
    treeState[path] = 'closed';
    const cache = this.state.cache;
    if (cache[path] && cache[path].isRejected()) {
      const cache = Object.assign({}, cache);
      delete cache[path];
    }
    this.setState({treeState, cache});
  },

  componentWillMount() {
    this.open(this.props.root);
  },

  getChildContext() {
    return {
      treeState: this.state.treeState,
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
