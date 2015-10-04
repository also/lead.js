import _ from 'underscore';
import d3 from 'd3';

const expandIsolatedValuesToLineSegments = function (values) {
  const result = [];
  let segmentLength = 0;
  let previous = null;

  const len = values.length;
  for (let i = 0; i < len; i++) {
    const v = values[i];
    if (v.value != null) {
      segmentLength++;
      previous = v;
    } else {
      if (segmentLength === 1) {
        result.push(previous);
      }
      segmentLength = 0;
    }
    result.push(v);
  }

  if (segmentLength === 1) {
    result.push(previous);
  }

  return result;
};

const simplifyPoints = function (minDistance, values) {
  const result = [];
  let previous = null;

  const len = values.length;
  for (let i = 0; i < len; i++) {
    const v = values[i];
    if (previous != null) {
      if ((previous.y != null) !== (v.y != null)) {
        result.push(v);

        if (v.y != null) {
          previous = v;
        }
      } else if (v.y != null) {
        const deltaX = Math.abs(v.x - previous.x);
        const deltaY = Math.abs(v.y - previous.y);

        if (Math.sqrt(deltaX * deltaX + deltaY * deltaY) > minDistance) {
          previous = v;
          result.push(v);
        }
      }
    } else {
      previous = v;
      result.push(v);
    }
  }

  return result;
};

const nullToZero = function (v) {
  return v != null ? v : 0;
};

const timestampBisector = d3.bisector((d) => d.timestamp);

export const transformData = function (data, params, sizes) {
  const color = d3.scale.ordinal().range(params.d3_colors);
  let allNames = [];
  allNames = _.uniq(allNames.concat.apply(allNames, _.pluck(data, 'target')));

  const colorsByName = {};
  allNames.forEach((name, i) => colorsByName[name] = color(i));

  const x = d3.scale.linear();
  const y = d3.scale.linear();
  x.range([0, sizes.width]);
  y.range([sizes.height, 0]);

  const area = d3.svg.area()
    .x((d) => d.x)
    .y0((d) => y(d.y0 != null ? d.y0 : 0))
    .y1((d) => y(d.value + (d.y0 != null ? d.y0 : 0)))
    .defined((d) => d.value != null);

  const line = d3.svg.line()
    .x((d) => d.x)
    .y((d) => y(d.value))
    .defined((d) => d.value != null);

  const stack = d3.layout.stack()
    .values((d) => d.values)
    .x((d) => d.timestamp)
    .y((d) => d.value)
    .out((d, y0, y) => {
      d.y0 = y0;
      d.value = y;
    })
    .offset(params.areaOffset);

  if (params.interpolate != null) {
    line.interpolate(params.interpolate);
    area.interpolate(params.interpolate);
  }

  let simplify;
  if (params.simplify) {
    simplify = _.partial(simplifyPoints, params.simplify);
  } else {
    simplify = _.identity;
  }

  let valueMin = null;
  let valueMax = null;
  let timeMin = null;
  let timeMax = null;

  const targets = data.map((s, targetIndex) => {
    const options = Object.assign({}, params, s.options);
    const {drawAsInfinite, getValue, getTimestamp} = options;

    const transformValue = params.drawNullAsZero ?
      nullToZero :
      _.identity;

    const {datapoints} = s;
    const len = datapoints.length;
    const values = new Array(len);
    for (let i = 0; i < len; i++) {
      const datapoint = datapoints[i];
      const value = transformValue(getValue(datapoint, i, targetIndex));
      const timestamp = 1000 * getTimestamp(datapoint, i, targetIndex);

      timeMin = Math.min(timestamp, timeMin != null ? timeMin : timestamp);
      timeMax = Math.max(timestamp, timeMax);

      if (!drawAsInfinite) {
        if (value != null) {
          valueMin = Math.min(value, valueMin != null ? valueMin : value);
        }
        if (value != null) {
          valueMax = Math.max(value, valueMax != null ? valueMax : value);
        }
      }

      values[i] = ({
        value,
        timestamp,
        original: datapoint
      });
    }

    const bisector = timestampBisector;

    const lineMode = params.areaMode === 'all' || params.areaMode === 'stacked' ? 'area' : params.areaMode === 'first' && targetIndex === 0 ? 'area' : 'line';
    const lineFn = lineMode === 'line' ? line : area;
    const name = s.target;
    const targetColor = options.color != null ? options.color : colorsByName[name];

    // FIXME these are unused
    // const areaAlpha = options.areaAlpha != null ? options.areaAlpha : options.alpha;
    // const lineAlpha = options.lineAlpha != null ? options.lineAlpha : options.alpha;
    // const pointAlpha = options.pointAlpha != null ? options.pointAlpha : options.alpha;

    return Object.assign(options, {
      values,
      bisector,
      name,
      lineMode,
      lineFn,
      color: targetColor,
      index: targetIndex
    });
  });

  if (params.areaMode === 'stacked' && targets.length > 0) {
    stack(targets);
    valueMin = null;
    valueMax = null;

    targets.forEach(({values}) => {
      const len = values.length;
      for (let i = 0; i < len; i++) {
        let {value, y0} = values[i];
        value += y0;
        valueMin = Math.min(value, valueMin);
        valueMax = Math.max(value, valueMax);
      }
    });
  }

  if (valueMin === valueMax) {
    valueMin = Math.round(valueMin) - 1;
    valueMax = Math.round(valueMax) + 1;
  }

  y.domain([params.yMin != null ? params.yMin : valueMin, params.yMax != null ? params.yMax : valueMax]);
  x.domain([params.xMin != null ? params.xMin : timeMin, params.xMax != null ? params.xMax : timeMax]);

  targets.forEach((target) => {
    const {values, drawNullAsZero} = target;

    const len = values.length;
    for (let i = 0; i < len; i++) {
      const v = values[i];
      if (v.value != null) {
        v.y = y(v.value);
      }

      v.x = x(v.timestamp);
    }

    let filterScatterValues;
    let expandLineValues;

    if (drawNullAsZero) {
      filterScatterValues = simplify;
      expandLineValues = simplify;
    } else {
      // TODO this won't work well with stack
      filterScatterValues = (values) => {
        return simplify(_.filter(values, (d) => d.value != null));
      };
      expandLineValues = _.compose(expandIsolatedValuesToLineSegments, simplify);
    }
    target.lineValues = expandLineValues(values);
    target.scatterValues = filterScatterValues(values);
  });

  return {
    targets: targets,
    valueMin: valueMin,
    valueMax: valueMax,
    timeMin: timeMin,
    timeMax: timeMax,
    xScale: x,
    yScale: y
  };
};

export const computeSizes = function (data, params) {
  let {width, height} = params;
  const legendRowHeight = 18;

  const margin = {
    top: 20,
    right: 80,
    bottom: 10,
    left: 80
  };

  if (params.title) {
    margin.top += 30;
  }

  width -= margin.left + margin.right;
  height -= margin.top + margin.bottom;

  let legendRowCount = data.length;
  let legendHeight;

  if (!params.hideLegend) {
    if ((params.legendMaxHeight != null) && data.length * legendRowHeight > params.legendMaxHeight) {
      legendRowCount = Math.floor(params.legendMaxHeight / legendRowHeight);
    }
    legendHeight = legendRowCount * legendRowHeight;
  } else {
    legendHeight = 0;
  }

  if (params.fixedHeight) {
    height -= legendHeight;
  }

  const svgWidth = width + margin.left + margin.right;
  const svgHeight = height + margin.top + margin.bottom + 30 + legendHeight;

  return {
    width: width,
    height: height,
    margin: margin,
    svgWidth: svgWidth,
    svgHeight: svgHeight,
    legendRowCount: legendRowCount,
    legendRowHeight: legendRowHeight,
    legendHeight: legendHeight
  };
};

export const targetValueAtTimestamp = function (target, timestamp) {
  const i = target.bisector.left(target.values, timestamp, 1);
  const d0 = target.values[i - 1];
  const d1 = target.values[i];

  if (d0 && d1) {
    if (timestamp - d0.timestamp > d1.timestamp - timestamp) {
      return d1;
    } else {
      return d0;
    }
  } else if (d0) {
    return d0;
  }
};
