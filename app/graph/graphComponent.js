import React from 'react';
import Bacon from 'bacon.model';
import _ from 'underscore';
import d3 from 'd3';
import Q from 'q';

import {computeParams} from './params';
import {computeSizes, transformData, targetValueAtTime} from './utils';
import AxisComponent from './axisComponent';
import TargetComponent from './targetComponent';
import LegendComponent from './legendComponent';
import CrosshairComponent from './crosshairComponent';
import BrushComponent from './brushComponent';


export default React.createClass({
  propTypes: {
    params: React.PropTypes.object,
    data: React.PropTypes.array
  },

  getInitialState() {
    this.mousePosition = new Bacon.Bus();
    this.targetState = new Bacon.Model();

    return this.getUpdatedState(this.props);
  },

  getUpdatedState(props) {
    if (this.destroyFunctions) {
      this.destroyFunctions.forEach((f) => f());
    }
    this.destroyFunctions = [];

    if (props.params) {
      const data = props.data != null ? props.data : [];
      const params = computeParams(props.params);
      const sizes = computeSizes(data, params);

      const {targets, xScale, yScale} = transformData(data, params, sizes);

      const cursorModel = params.cursor != null ? params.cursor : new Bacon.Model();
      const brushModel = params.brush != null ? params.brush : new Bacon.Model({
        brushing: false
      });

      this.targetState.set({
        selection: _.map(targets, () => {
          return true;
        }),
        highlightIndex: null
      });

      const cursorBus = new Bacon.Bus();
      cursorBus.plug(this.mousePosition.map((p) => p.time));

      this.destroyFunctions.push(() => cursorBus.end());

      const externalCursorChanges = cursorModel.addSource(cursorBus);
      const boundedExternalCursorPosition = externalCursorChanges.map((time) => {
        const domain = xScale.domain();
        if (time < domain[0]) {
          time = domain[0];
        } else if (time > domain[1]) {
          time = domain[1];
        }

        return {
          x: xScale(time),
          time: time
        };
      });

      const cursorPosition = boundedExternalCursorPosition
        .merge(this.mousePosition)
        .map(({x, time}) => {
          const targetValues = targets.map((t) => targetValueAtTime(t, time));

          return {x, time, targetValues};
        });

      return {
        targets,
        xScale,
        yScale,
        params,
        sizes,
        cursorPosition,
        brushModel
      };
    } else {
      return {};
    }
  },

  componentWillReceiveProps(props) {
    this.setState(this.getUpdatedState(props));
  },

  onMouseMove(e) {
    d3.event = e.nativeEvent;
    try {
      const pos = d3.mouse(this.refs.chartArea.getDOMNode());
      if (pos[1] >= 0 && pos[1] <= this.state.sizes.height) {
        const xConstrained = Math.max(0, Math.min(pos[0], this.state.sizes.width));
        return this.mousePosition.push({
          time: this.state.xScale.invert(xConstrained),
          value: this.state.yScale.invert(pos[1]),
          x: xConstrained,
          y: pos[1]
        });
      }
    } finally {
      d3.event = null;
    }
  },

  onTargetClick(target) {
    this.targetState.modify((m) => {
      m = _.clone(m);
      m.selection[target.index] = !m.selection[target.index];
      return m;
    });
  },

  onTargetMouseOver(target) {
    this.targetState.modify((m) => {
      m = _.clone(m);
      m.highlightIndex = target.index;
      return m;
    });
  },

  onTargetMouseOut() {
    this.targetState.modify((m) => {
      m = _.clone(m);
      m.highlightIndex = null;
      return m;
    });
  },

  childContextTypes: {
    sizes: React.PropTypes.object,
    params: React.PropTypes.object,
    xScale: React.PropTypes.func,
    yScale: React.PropTypes.func,
    cursorPosition: React.PropTypes.object,
    targetState: React.PropTypes.object,
    clipPath: React.PropTypes.string
  },

  getChildContext() {
    const context = _.pick(this.state, Object.keys(this.constructor.childContextTypes));
    context.targetState = this.targetState;
    context.clipPath = 'url(#clipper)';
    return context;
  },

  exportImage() {
    const svg = this.refs.svg.getDOMNode();
    const deferred = Q.defer();
    const canvas = document.createElement('canvas');
    const rect = svg.getBoundingClientRect();
    canvas.width = rect.width;
    canvas.height = rect.height;
    const ctx = canvas.getContext('2d');
    const svgString = new XMLSerializer().serializeToString(svg);
    const svgBlob = new Blob([svgString], {
      type: 'image/svg+xml;charset=utf-8'
    });
    const url = URL.createObjectURL(svgBlob);
    const img = new Image();
    img.src = url;
    img.onload = () => {
      ctx.drawImage(img, 0, 0);
      // would like to return a blob, but https://code.google.com/p/chromium/issues/detail?id=67587
      const dataUrl = canvas.toDataURL();
      return deferred.resolve(dataUrl);
    };
    img.onerror = (e) => {
      return deferred.reject(e);
    };
    return deferred.promise.finally(() => {
      URL.revokeObjectURL(url);
    });
  },

  render() {
    if (this.state.params) {
      const {targets, params, sizes, xScale, yScale} = this.state;

      let title = null;
      if (params.title != null) {
        title = <text
                  key='title'
                  x={sizes.margin.left + sizes.width / 2}
                  y={10}
                  dy={params.titleTextSize}
                  fill={params.titleTextColor}
                  style={{'font-size': params.titleTextSize, 'font-weight': 'bold'}}>{params.title}</text>;
      }

      let xAxis = null;
      if (!(params.hideXAxis || params.hideAxes)) {
        xAxis = <g key='xAxis' transform={`translate(0, ${sizes.height})`}>
          <AxisComponent axis={d3.svg.axis().scale(xScale).orient('bottom').ticks(params.xAxisTicks)}/>
        </g>;
      }

      let yAxis = null;
      if (!(params.hideYAxis || params.hideAxes)) {
        yAxis = <g key='yAxis'>
          <AxisComponent axis={d3.svg.axis().scale(yScale).orient('left').ticks(params.yAxisTicks)}/>
        </g>;
      }

      const plots = targets.map((d, i) => {
        return <g key={i} onClick={() => this.onTargetClick(d)} onMouseOver={() => this.onTargetMouseOver(d)} onMouseOut={() => this.onTargetMouseOut(d)}>
          <TargetComponent target={d} hover={false}/>
          <TargetComponent target={d} hover={true}/>
        </g>;
      });

      let legend = null;
      if (!params.hideLegend) {
        legend = <LegendComponent targets={targets} mouseHandler={this}/>;
      }

      // react doesn't support clipPath :(
      const clipper = `
      <clipPath id='clipper'>
          <rect width="${sizes.width}" height="${sizes.height}"/>
      </clipPath>`;

      const svg =
        <svg width={sizes.svgWidth} height={sizes.svgHeight}
            ref='svg'
            style={{'font-family': '"Helvetica Neue"', cursor: 'default', 'background-color': params.bgcolor}}
            onMouseMove={this.onMouseMove}>
          {title}
          <g dangerouslySetInnerHTML={{__html: clipper}}/>

          <g transform={`translate(${sizes.margin.left},${sizes.margin.top})`} ref='chartArea'>
            {xAxis}
            {yAxis}
            <CrosshairComponent/>
            <BrushComponent brushModel={this.state.brushModel}/>
            <g key='targets'>{plots}</g>
            {legend}
          </g>
        </svg>;

      return <div className='graph'>
        {svg}
      </div>;
    } else {
      return null;
    }
  }
});
