import d3 from 'd3';

import colorbrewer from './lib/colorbrewer';

const colors = {
  d3: {},
  brewer: colorbrewer
};

['category10', 'category20', 'category20b', 'category20c'].forEach((k) => {
  // dammit, d3
  colors.d3[k] = d3.scale[k]().range();
});

export default colors;
