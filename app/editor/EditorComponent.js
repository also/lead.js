import * as React from 'react/addons';

import ContextAwareMixin from '../context/ContextAwareMixin';
import {create_editor} from '../editor';


export default React.createClass({
  propTypes: {
    run: React.PropTypes.func.isRequired,
    initial_value: React.PropTypes.string
  },

  mixins: [ContextAwareMixin],

  getInitialState() {
    return {
      editor: create_editor('context')
    };
  },

  run() {
    return this.props.run(this.state.editor.getValue());
  },

  componentDidMount() {
    const {editor} = this.state;

    editor.ctx = this.ctx();
    editor.run = this.run;
    this.getDOMNode().appendChild(editor.display.wrapper);
    if (this.props.initial_value != null) {
      editor.setValue(this.props.initial_value);
    }
    return editor.refresh();
  },

  get_value() {
    return this.state.editor.getValue();
  },

  render() {
    return <div className='code'/>;
  }
});
