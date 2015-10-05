import React from 'react/addons';

import OutputCellComponent from './OutputCellComponent';


export default React.createClass({
  mixins: [React.addons.PureRenderMixin],

  getInitialState() {
    return {outputHeight: 0};
  },

  render() {
    const {inputCell, outputCell, useMinHeight} = this.props;

    const minHeight = useMinHeight ? this.state.outputHeight : 0;

    let input, output;
    if (inputCell) {
      input = React.createElement(inputCell.component, {
        cell: inputCell,
        key: inputCell.cellId,
        minHeight: minHeight
      });
    } else {
      input = <div className='placeholder cell'/>;
    }

    if (outputCell) {
      output = <OutputCellComponent
        cell={outputCell}
        key={outputCell.cellId}
        ref='output'/>;
    } else {
      output = <div className='placeholder cell'/>;
    }

    return (
      <div className='io'>
        {input}
        {output}
      </div>
    );
  },

  onAnimationFrame() {
    this._animationFrame = requestAnimationFrame(this.onAnimationFrame);
    const {output} = this.refs;
    const newHeight = output ? output.getWrappedInstance().getOutputHeight() : 0;

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
