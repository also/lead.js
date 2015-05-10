import _ from 'underscore';

export const scopedEval = function(ctx, string, var_names) {
  if (var_names == null) {
    var_names = [];
  }
  if (_.isFunction(string)) {
    string = "(" + string + ").apply(this);";
  }
  _.each(var_names, function(name) {
    var _base;
    return (_base = ctx.repl_vars)[name] != null ? _base[name] : _base[name] = void 0;
  });

  /*eslint-disable no-with */
  with (ctx.scope) { with (ctx.repl_vars) {
    return eval(string);
  }};
  /*eslint-enable no-with */
};
