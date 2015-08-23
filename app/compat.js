import Q from 'q';
import _ from 'underscore';
import moment from 'moment';
import CodeMirror from 'codemirror';
import d3 from 'd3';
import * as Context from './context';
import colors from './colors';
import * as modules from './modules';
import React from 'react';

const requireables = {
  q: Q,
  _,
  moment,
  colors,
  d3,
  react: React
};

modules.export(exports, 'compat', ({fn, contextExport}) => {
  fn('require', (ctx, moduleName) => {
    return Context.value(requireables[moduleName] || ctx.modules[moduleName]);
  });

  return contextExport({
    moment,
    CodeMirror,
    _,
    ignore: Context.IGNORE
  });
});
