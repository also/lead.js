import _ from 'underscore';
import d3 from 'd3';

import colors from '../colors';

const commaInt = d3.format(',.f');
const commaDec = d3.format(',.3f');

const valueFormat = function (n) {
  if (n % 1 === 0) {
    return commaInt(n);
  } else {
    return commaDec(n);
  }
};

const defaultParams = {
  width: 800,
  height: 400,
  type: 'line',
  getValue: (dp) => dp[1],
  getTimestamp: (dp) => dp[0],
  d3_colors: colors.d3.category10,
  areaAlpha: null,
  lineAlpha: null,
  pointAlpha: null,
  alpha: 1.0,
  bgcolor: '#fff',
  areaMode: 'none',
  areaOffset: 'zero',
  drawNullAsZero: false,
  simplify: 0.5,
  axisLineColor: '#ccc',
  axisTextColor: '#aaa',
  axisTextSize: '10px',
  crosshairLineColor: '#ddd',
  crosshairTextColor: '#aaa',
  crosshairTextSize: '10px',
  crosshairValueTextColor: '#aaa',
  brushColor: '#efefef',
  valueFormat: valueFormat,
  hideAxes: false,
  hideLegend: false,
  hideXAxis: false,
  hideYAxis: false,
  title: null,
  titleTextSize: '12px',
  titleTextColor: '#333',
  legendTextColor: '#333',
  legendText: (d) => d.name,
  deselectedOpacity: 0.5,
  lineWidth: 1,
  drawAsInfinite: false,
  radius: 2,
  fixedHeight: false,
  legendMaxHeight: null,
  xAxisTicks: 10,
  yAxisTicks: 10,
  lineOpacity: 1.0
};

const fgColorParams = [
  'axisLineColor',
  'axisTextColor',
  'crosshairLineColor',
  'crosshairTextColor',
  'titleTextColor',
  'legendTextColor'
];

export const computeParams = function (params) {
  let computedParams;
  if (params && params.fgcolor) {
    computedParams = _.object(fgColorParams.map((k) => [k, params.fgcolor]));
  } else {
    computedParams = {};
  }

  return Object.assign({}, defaultParams, computedParams, params);
};
