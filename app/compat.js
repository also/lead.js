import Q from 'q';
import _ from 'underscore';
import moment from 'moment';
import CodeMirror from 'codemirror';
import d3 from 'd3';
import * as Context from './context';
import colors from './colors';
import * as modules from './modules';

const requireables = {
  q: Q,
  _: _,
  moment: moment,
  colors: colors,
  d3: d3
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
