import React from 'react/addons';

import {ObservableMixin} from '../components';


export default React.createClass({
  mixins: [ObservableMixin, React.addons.PureRenderMixin],

  getObservable(props) {
    return props.cell.component_model;
  },

  getOutputHeight() {
    return this.refs.output.getDOMNode().clientHeight;
  },

  render() {
    const {cell} = this.props;
    const {value} = this.state;

    return (
      <div className='output-cell-wrapper'>
        <div className='cell output' data-cell-number={cell.number} ref='output'>
          {value ? value() : null}
        </div>
      </div>
    );
  },

  componentDidMount() {
    this.props.cell.dom_node = this.getDOMNode();
  }
});
