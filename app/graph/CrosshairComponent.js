import React from 'react';
import moment from 'moment';

import CursorPositionMixin from './CursorPositionMixin';

export default React.createClass({
  mixins: [CursorPositionMixin],

  contextTypes: {
    params: React.PropTypes.object.isRequired,
    sizes: React.PropTypes.object.isRequired
  },

  render() {
    if (this.state.value) {
      const {params, sizes} = this.context;
      const {height} = sizes;

      const {x, time} = this.state.value;

      return <g>
        <line style={{'shape-rendering': 'crispEdges'}}
              x1={x}
              x2={x}
              y1={0}
              y2={height}
              stroke={params.crosshairLineColor}/>
        <text x={x}
              y='-6'
              fill={params.crosshairTextColor}
              style={{'text-anchor': 'middle', 'font-size': params.crosshairTextSize}}>
          {moment(time).format('lll')}
        </text>
      </g>;
    } else {
      return null;
    }
  }
});
