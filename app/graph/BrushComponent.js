import React from 'react';
import d3 from 'd3';
import Bacon from 'bacon.model';

function sets(newValue) {
  return (v) => Object.assign({}, v, newValue);
}

export default React.createClass({
  propTypes: {
    brushModel: React.PropTypes.object.isRequired
  },

  contextTypes: {
    xScale: React.PropTypes.func.isRequired,
    sizes: React.PropTypes.object.isRequired,
    params: React.PropTypes.object.isRequired
  },

  createBrush() {
    return d3.svg.brush().x(this.context.xScale).on('brush', this.onBrush).on('brushstart', this.onBrushStart).on('brushend', this.onBrushEnd);
  },

  onBrush() {
    const brush = d3.event.target;
    this.brushBus.push(brush.empty() ? sets({extent: null}) : sets({extent: brush.extent()}));
  },

  onBrushStart() {
    this.brushBus.push(sets({brushing: true}));
  },

  onBrushEnd() {
    this.brushBus.push(sets({brushing: false}));
  },

  setExtent(context, extent) {
    const {xScale} = context;
    const domain = xScale.domain();

    if (extent != null) {
      this.brush.extent([Math.min(Math.max(domain[0], extent[0]), domain[1]), Math.max(Math.min(domain[1], extent[1]), domain[0])]);
    } else {
      this.brush.clear();
    }

    return this.selection.call(this.brush);
  },

  unsubscribe() {
    if (this.brushBus) {
      this.brushBus.end();
    }
    if (this.brushModelUnsubscribe) {
      this.brushModelUnsubscribe();
    }
  },

  update(props, context) {
    const {brushModel} = props;

    this.selection.selectAll('rect')
      .attr('y', 0)
      .attr('height', context.sizes.height)
      .attr('fill', context.params.brushColor);

    this.brush.x(context.xScale);
    this.setExtent(context, null);
    this.unsubscribe();
    this.brushBus = new Bacon.Bus();

    const externalChanges = brushModel.apply(this.brushBus);
    this.brushModelUnsubscribe = externalChanges.onValue(({extent}) => {
      this.setExtent(context, extent);
    });
  },

  render() {
    return <g/>;
  },

  componentDidMount() {
    this.selection = d3.select(this.getDOMNode());
    this.brush = this.createBrush();
    this.selection.call(this.brush);
    return this.update(this.props, this.context);
  },

  componentWillReceiveProps(props, context) {
    return this.update(props, context);
  },

  componentWillUnmount() {
    return this.unsubscribe();
  }
});
