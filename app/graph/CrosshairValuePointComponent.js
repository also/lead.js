import React from 'react';

import CursorPositionMixin from './CursorPositionMixin';

export default React.createClass({
  mixins: [CursorPositionMixin],
  propTypes: {
    target: React.PropTypes.object.isRequired
  },

  contextTypes: {
    params: React.PropTypes.object.isRequired,
    yScale: React.PropTypes.func.isRequired
  },

  render() {
    const {params, yScale} = this.context;
    const {target} = this.props;
    const [max, min] = yScale.range();

    let radius;
    if (target.type === 'scatter') {
      radius = target.radius + 3;
    } else {
      radius = 4;
    }

    if (this.state.value) {
      const d = this.state.value.targetValues[target.index];

      if (d.y < min || d.y > max) {
        return null;
      } else {
        const visibility = d.value != null ? 'visible' : 'hidden';
        return <circle
                  fill={target.color}
                  stroke={params.bgcolor}
                  style={{strokeWidth: 2, visibility}}
                  cx={d.x}
                  cy={d.y}
                  r={radius}/>;
      }
    } else {
      return null;
    }
  }
});
