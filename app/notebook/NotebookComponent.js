import React from 'react/addons';
import {Provider} from 'react-redux';

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

    return (
      <Provider store={notebook.store}>
        {() => <DocumentComponent/>}
      </Provider>
    );
  },

  componentWillUnmount() {
    destroyNotebook(this.state.notebook);
  }
});
