import React from 'react/addons';

export default React.createClass({
  displayName: 'InputOutputComponent',
  mixins: [React.addons.PureRenderMixin],
  getInitialState() {
    return {
      outputHeight: 0
    };
  },
  render() {
    let input, minHeight, output;
    if (this.props.useMinHeight) {
      minHeight = this.state.outputHeight;
    } else {
      minHeight = 0;
    }
    if (this.props.input_cell) {
      input = this.props.input_cell.component({
        cell: this.props.input_cell,
        key: this.props.input_cell.key,
        minHeight: minHeight
      });
    } else {
      input = React.DOM.div({
        className: 'placeholder cell'
      });
    }
    if (this.props.output_cell) {
      output = this.props.output_cell.component({
        cell: this.props.output_cell,
        key: this.props.output_cell.key,
        ref: 'output'
      });
    } else {
      output = React.DOM.div({
        className: 'placeholder cell'
      });
    }
    return React.DOM.div({
      className: 'io'
    }, input, output);
  },
  onAnimationFrame() {
    let ref, ref1;
    this._animationFrame = requestAnimationFrame(this.onAnimationFrame);
    const newHeight = (ref = (ref1 = this.refs.output) != null ? ref1.getOutputHeight() : void 0) != null ? ref : 0;

    if (newHeight !== this.state.outputHeight) {
      return this.setState({
        outputHeight: newHeight
      });
    }
  },
  componentDidMount() {
    return this.onAnimationFrame();
  },
  componentWillUnmount() {
    return cancelAnimationFrame(this._animationFrame);
  }
});
