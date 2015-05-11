import React from 'react';

export default React.createClass({
  contextTypes: {
    yScale: React.PropTypes.func.isRequired
  },

  propTypes: {
    target: React.PropTypes.object.isRequired,
    hover: React.PropTypes.bool,
    highlighted: React.PropTypes.bool
  },

  render() {
    const d = this.props.target;
    const {yScale} = this.context;

    const [max, min] = yScale.range();

    let extraRadius;
    if (this.props.hover) {
      extraRadius = 3;
    } else {
      extraRadius = 0;
    }

    if (this.props.highlighted) {
      extraRadius += 3;
    }

    const circleColor = d.color;
    const radius = d.radius + extraRadius;

    const circles = d.scatterValues.map((v, i) => {
      if (v.y < min || v.y > max) {
        return null;
      } else {
        return <circle key={i}
                       cx={v.x}
                       cy={v.y}
                       fill={circleColor}
                       r={radius}
                       style={{'fill-opacity': d.pointAlpha}}/>;
      }
    });

    return <g>{circles}</g>;
  }
});
