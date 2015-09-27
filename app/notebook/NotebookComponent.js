import React from 'react/addons';
import {connect} from 'react-redux';

import {createNotebook, actions} from '../notebook';

import DocumentComponent from './DocumentComponent';


const {notebookCreated, notebookDestroyed} = actions;

export default connect(null, {notebookCreated, notebookDestroyed})(React.createClass({
  propTypes: {
    imports: React.PropTypes.arrayOf(React.PropTypes.string).isRequired,
    modules: React.PropTypes.object.isRequired,
    init: React.PropTypes.func
  },

  getInitialState() {
    const notebook = createNotebook(this.props);

    this.props.notebookCreated(notebook);

    const {init} = this.props;
    if (init) {
      init(notebook);
    }
    return {notebook};
  },

  shouldComponentUpdate() {
    return false;
  },

  render() {
    const {notebook} = this.state;

    return <DocumentComponent notebookId={notebook.notebookId}/>;
  },

  componentWillUnmount() {
    this.props.notebookDestroyed(this.state.notebook.notebookId);
  }
}));
