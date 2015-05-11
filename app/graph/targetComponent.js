import React from 'react';

import {ObservableMixin} from '../components';
import LineComponent from './lineComponent';
import InfiniteLinesComponent from './infiniteLinesComponent';
import ScatterComponent from './scatterComponent';
import CrosshairValuePointComponent from './crosshairValuePointComponent';

export default React.createClass({
  mixins: [ObservableMixin],

  propTypes: {
    target: React.PropTypes.object.isRequired,
    hover: React.PropTypes.bool
  },

  contextTypes: {
    params: React.PropTypes.object.isRequired,
    targetState: React.PropTypes.object.isRequired
  },

  getObservable(props, context) {
    return context.targetState;
  },

  render() {
    const {params} = this.context;
    const d = this.props.target;
    const {drawAsInfinite, type} = d;

    const selected = this.state.value.selection[d.index];
    const highlighted = this.state.value.highlightIndex === d.index;
    const DataHandler = drawAsInfinite ? InfiniteLinesComponent : type === 'line' ? LineComponent : ScatterComponent;
    const opacity = this.props.hover ? 0 : selected ? 1 : params.deselectedOpacity;

    const dataComponent = <DataHandler target={d} hover={this.props.hover} highlighted={highlighted}/>;

    if (this.props.hover) {
      return <g style={{opacity}}>
        {dataComponent}
      </g>;
    } else {
      return <g style={{opacity}}>
        {dataComponent}
        <CrosshairValuePointComponent target={d}/>
      </g>;
    }
  }
});
