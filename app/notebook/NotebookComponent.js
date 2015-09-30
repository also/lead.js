import React from 'react/addons';
import {connect} from 'react-redux';

import {createNotebook} from '../notebook';
import {notebookCreated, notebookDestroyed} from './actions';

import ContextAwareMixin from '../context/ContextAwareMixin';
import DocumentComponent from './DocumentComponent';


export default connect(null, {notebookCreated, notebookDestroyed})(React.createClass({
  propTypes: {
    init: React.PropTypes.func
  },

  mixins: [ContextAwareMixin],

  componentWillMount() {
    const notebook = createNotebook(this.ctx());

    this.props.notebookCreated(notebook);

    const {init} = this.props;
    if (init) {
      init(notebook.ctx, notebook);
    }

    this.notebook = notebook;
  },

  shouldComponentUpdate() {
    return false;
  },

  render() {
    const {notebook} = this;

    return <DocumentComponent notebookId={notebook.notebookId} ctx={notebook.ctx}/>;
  },

  componentWillUnmount() {
    this.props.notebookDestroyed(this.notebook.notebookId);
  }
}));
