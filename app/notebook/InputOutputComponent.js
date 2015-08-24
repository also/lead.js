import React from 'react/addons';

export default React.createClass({
  mixins: [React.addons.PureRenderMixin],

  getInitialState() {
    return {outputHeight: 0};
  },

  render() {
    const {input_cell, output_cell, useMinHeight} = this.props;

    const minHeight = useMinHeight ? this.state.outputHeight : 0;

    let input, output;
    if (input_cell) {
      input = React.createElement(input_cell.component, {
        cell: input_cell,
        key: input_cell.key,
        minHeight: minHeight
      });
    } else {
      input = <div className='placeholder cell'/>;
    }

    if (output_cell) {
      output = React.createElement(output_cell.component, {
        cell: output_cell,
        key: output_cell.key,
        ref: 'output'
      });
    } else {
      output = <div className='placeholder cell'/>;
    }

    return (
      <div className='io'>
        {input}
        {output}
      </div>
    )
  },

  onAnimationFrame() {
    this._animationFrame = requestAnimationFrame(this.onAnimationFrame);
    const {output} = this.refs;
    const newHeight = output ? output.getOutputHeight() : 0;

    if (newHeight !== this.state.outputHeight) {
      this.setState({outputHeight: newHeight});
    }
  },

  componentDidMount() {
    this.onAnimationFrame();
  },

  componentWillUnmount() {
    cancelAnimationFrame(this._animationFrame);
  }
});
