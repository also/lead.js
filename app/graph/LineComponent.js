import React from 'react';


const pathStyles = {
  line: {
    fill: 'none',
    strokeLinecap: 'square'
  }
};

export default React.createClass({
  contextTypes: {
    clipPath: React.PropTypes.string.isRequired
  },

  propTypes: {
    target: React.PropTypes.object.isRequired,
    hover: React.PropTypes.bool,
    highlighted: React.PropTypes.bool
  },

  render() {
    const d = this.props.target;
    const {clipPath} = this.context;

    let extraWidth;
    if (this.props.hover) {
      extraWidth = 10;
    } else {
      extraWidth = 0;
    }

    if (this.props.highlighted) {
      extraWidth += 3;
    }

    const style = Object.assign({
      strokeWidth: d.lineWidth + extraWidth,
      strokeOpacity: d.lineAlpha,
      fillOpacity: d.areaAlpha
    }, pathStyles[d.lineMode]);

    return <path stroke={d.color}
                 style={style}
                 fill={d.lineMode === 'area' ? d.color : null}
                 d={d.lineFn(d.lineValues)}
                 clipPath={clipPath}/>;
  }
});
