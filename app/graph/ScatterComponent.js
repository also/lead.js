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
    const {target, hover, highlighted} = this.props;
    const {yScale} = this.context;

    const [max, min] = yScale.range();

    let extraRadius;
    if (hover) {
      extraRadius = 3;
    } else {
      extraRadius = 0;
    }

    if (highlighted) {
      extraRadius += 3;
    }

    const circleColor = target.color;
    const radius = target.radius + extraRadius;

    const circles = target.scatterValues.map((v, i) => {
      if (v.y < min || v.y > max) {
        return null;
      } else {
        return <circle key={i}
                       cx={v.x}
                       cy={v.y}
                       fill={circleColor}
                       r={radius}
                       style={{fillOpacity: target.pointAlpha}}/>;
      }
    });

    return <g>{circles}</g>;
  }
});
