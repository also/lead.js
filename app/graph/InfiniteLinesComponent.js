import React from 'react';

export default React.createClass({
  propTypes: {
    target: React.PropTypes.object.isRequired,
    hover: React.PropTypes.bool,
    highlighted: React.PropTypes.bool
  },

  contextTypes: {
    sizes: React.PropTypes.object.isRequired
  },

  render() {
    const d = this.props.target;

    let extraWidth;
    if (this.props.hover) {
      extraWidth = 10;
    } else {
      extraWidth = 0;
    }

    if (this.props.highlighted) {
      extraWidth += 3;
    }

    const lineColor = d.color;
    const lineWidth = d.lineWidth + extraWidth;
    const {height} = this.context.sizes;

    const lines = d.scatterValues.map((v, i) => {
      if (v.value) {
        return <line key={i}
                     x1={v.x}
                     x2={v.x}
                     y1={0}
                     y2={height}
                     stroke={lineColor}
                     style={{strokeOpacity: d.lineAlpha, strokeWidth: lineWidth}}/>;
      }
    });

    return <g>{lines}</g>;
  }
});
