import React from 'react/addons';

import {connect} from 'react-redux';

import {actions} from '../notebook';


export default connect(null, actions)(React.createClass({
  mixins: [React.addons.PureRenderMixin],

  getOutputHeight() {
    return this.refs.output.getDOMNode().clientHeight;
  },

  render() {
    const {cell: {component}, number} = this.props;

    return (
      <div className='output-cell-wrapper'>
        <div className='cell output' data-cell-number={number} ref='output'>
          {component ? component() : null}
        </div>
      </div>
    );
  },

  componentDidMount() {
    this.props.updateCell(this.props.cell.key, {dom_node: this.getDOMNode()});
  }
}));
