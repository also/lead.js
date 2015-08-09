import React from 'react/addons';

import {ObservableMixin} from '../components';


export default React.createClass({
  displayName: 'OutputCellComponent',
  mixins: [ObservableMixin, React.addons.PureRenderMixin],

  getObservable(props) {
    return props.cell.component_model;
  },

  getOutputHeight() {
    return this.refs.output.getDOMNode().clientHeight;
  },

  render() {
    let base;
    return React.DOM.div({
      className: 'output-cell-wrapper'
    }, React.DOM.div({
      className: 'cell output',
      'data-cell-number': this.props.cell.number,
      ref: 'output'
    }, typeof (base = this.state).value === 'function' ? base.value() : void 0));
  },

  componentDidMount() {
    this.props.cell.dom_node = this.getDOMNode();
  }
});
