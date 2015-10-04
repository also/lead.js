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
    const {target, hover, highlighted} = this.props;
    const {clipPath} = this.context;

    let extraWidth;
    if (hover) {
      extraWidth = 10;
    } else {
      extraWidth = 0;
    }

    if (highlighted) {
      extraWidth += 3;
    }

    const style = Object.assign({
      strokeWidth: target.lineWidth + extraWidth,
      strokeOpacity: target.lineAlpha,
      fillOpacity: target.areaAlpha
    }, pathStyles[target.lineMode]);

    return <path stroke={target.color}
                 style={style}
                 fill={target.lineMode === 'area' ? target.color : null}
                 d={target.lineFn(target.lineValues)}
                 clipPath={clipPath}/>;
  }
});
