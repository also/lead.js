import React from 'react/addons';

import {createNotebook, destroyNotebook} from '../notebook';

import DocumentComponent from './DocumentComponent';

export default React.createClass({
  propTypes: {
    imports: React.PropTypes.arrayOf(React.PropTypes.string).isRequired,
    modules: React.PropTypes.object.isRequired,
    init: React.PropTypes.func
  },

  getInitialState() {
    const notebook = createNotebook(this.props);

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
    destroyNotebook(this.state.notebook);
  }
});
