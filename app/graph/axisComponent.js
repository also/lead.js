import React from 'react';
import d3 from 'd3';

export default React.createClass({
  propTypes: {
    axis: React.PropTypes.func.isRequired
  },

  contextTypes: {
    params: React.PropTypes.object.isRequired
  },

  render() {
    return <g/>;
  },

  componentDidMount() {
    this.drawAxis();
  },

  componentDidUpdate() {
    this.drawAxis();
  },

  drawAxis() {
    const {params} = this.context;
    const {axis} = this.props;

    const sel = d3.select(this.getDOMNode());

    sel.call(axis);

    sel.selectAll('path, line')
      .attr('stroke', params.axisLineColor)
      .attr({
        fill: 'none',
        'shape-rendering': 'crispEdges'
      });

    sel.selectAll('text')
      .attr('fill', params.axisTextColor)
      .style('font-size', params.axisTextSize);
  }
});
