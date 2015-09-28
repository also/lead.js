import React from 'react/addons';
import {connect} from 'react-redux';

import {createNotebook} from '../notebook';
import {notebookCreated, notebookDestroyed} from './actions';

import DocumentComponent from './DocumentComponent';


export default connect(null, {notebookCreated, notebookDestroyed})(React.createClass({
  propTypes: {
    imports: React.PropTypes.arrayOf(React.PropTypes.string).isRequired,
    modules: React.PropTypes.object.isRequired,
    init: React.PropTypes.func
  },

  contextTypes: {
    store: React.PropTypes.object.isRequired
  },

  getInitialState() {
    const {store} = this.context;
    const notebook = createNotebook(Object.assign({store}, this.props));

    this.props.notebookCreated(notebook);

    const {init} = this.props;
    if (init) {
      init(notebook.ctx, notebook);
    }
    return {notebook};
  },

  shouldComponentUpdate() {
    return false;
  },

  render() {
    const {notebook} = this.state;

    return <DocumentComponent notebookId={notebook.notebookId} ctx={notebook.ctx}/>;
  },

  componentWillUnmount() {
    this.props.notebookDestroyed(this.state.notebook.notebookId);
  }
}));
