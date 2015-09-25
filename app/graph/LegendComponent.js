import React from 'react';

import {ObservableMixin} from '../components';
import CursorPositionMixin from './CursorPositionMixin';

const LegendCrosshairValueComponent = React.createClass({
  mixins: [CursorPositionMixin],
  propTypes: {
    target: React.PropTypes.object.isRequired
  },
  contextTypes: {
    params: React.PropTypes.object.isRequired
  },

  render() {
    const {params} = this.context;
    const {target} = this.props;

    let text;
    if (this.state.value) {
      const targetValue = this.state.value.targetValues[target.index];
      text = params.valueFormat(targetValue != null ? targetValue.value : null);
    } else {
      text = '';
    }

    return <tspan fill={params.crosshairValueTextColor}>{text}</tspan>;
  }
});

export default React.createClass({
  mixins: [ObservableMixin],

  propTypes: {
    targets: React.PropTypes.array.isRequired,
    mouseHandler: React.PropTypes.object.isRequired
  },

  contextTypes: {
    sizes: React.PropTypes.object.isRequired,
    params: React.PropTypes.object.isRequired,
    targetState: React.PropTypes.object.isRequired
  },

  getObservable() {
    return this.context.targetState;
  },

  render() {
    const {sizes, params} = this.context;

    const {targets, mouseHandler} = this.props;

    const legendEntries = targets.slice(0, sizes.legendRowCount).map((d, i) => {
      const selected = this.state.value.selection[d.index];
      const highlighted = this.state.value.highlightIndex === d.index;

      let offset;
      let size;
      if (highlighted) {
        offset = 2;
        size = 10;
      } else {
        offset = 4;
        size = 6;
      }
      const opacity = selected ? 1 : params.deselectedOpacity;

      return <g key={i} opacity={opacity} transform={`translate(0,${i * sizes.legendRowHeight})`}
                onClick={() => mouseHandler.onTargetClick(d)}
                onMouseOver={() => mouseHandler.onTargetMouseOver(d)}
                onMouseOut={() => mouseHandler.onTargetMouseOut(d)}>
        <rect x={offset} y={offset} width={size} height={size} fill={d.color}/>
        <text x='16' dy='11' style={{fontSize: '11px'}}>
          <tspan fill={params.legendTextColor}>{params.legendText(d)}</tspan>
          <tspan style={{whiteSpace: 'pre'}}>{'   '}</tspan>
          <LegendCrosshairValueComponent target={d}/>
        </text>
      </g>;
    });

    return <g transform={`translate(0,${sizes.height + 30})`}>{legendEntries}</g>;
  }
});
