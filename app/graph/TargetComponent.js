import React from 'react';

import {ObservableMixin} from '../components';
import CrosshairValuePointComponent from './CrosshairValuePointComponent';


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
    const {hover, target} = this.props;
    const {DataHandler} = target;
    const {value} = this.state;

    const selected = this.state.value.selection[target.index];
    const highlighted = value.highlightIndex === target.index;

    const opacity = hover ? 0 : selected ? 1 : params.deselectedOpacity;

    const dataComponent = <DataHandler target={target} hover={hover} highlighted={highlighted}/>;

    if (this.props.hover) {
      return <g style={{opacity}}>
        {dataComponent}
      </g>;
    } else {
      return <g style={{opacity}}>
        {dataComponent}
        <CrosshairValuePointComponent target={target}/>
      </g>;
    }
  }
});
