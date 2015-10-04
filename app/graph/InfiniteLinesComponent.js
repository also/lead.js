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
    const {target, hover, highlighted} = this.props;
    const {sizes: {height}} = this.context;

    let extraWidth;
    if (hover) {
      extraWidth = 10;
    } else {
      extraWidth = 0;
    }

    if (highlighted) {
      extraWidth += 3;
    }

    const lineColor = target.color;
    const lineWidth = target.lineWidth + extraWidth;

    const lines = target.scatterValues.map((v, i) => {
      if (v.value) {
        return <line key={i}
                     x1={v.x}
                     x2={v.x}
                     y1={0}
                     y2={height}
                     stroke={lineColor}
                     style={{strokeOpacity: target.lineAlpha, strokeWidth: lineWidth}}/>;
      }
    });

    return <g>{lines}</g>;
  }
});
