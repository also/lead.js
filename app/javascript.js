import acorn from 'acorn';
import walk from 'acorn/util/walk';
import _ from 'underscore';


export function mangle(src) {
  const ast = acorn.parse(src, {ranges: true, locations: true});
  const chunks = src.split('');

  function source(node) {
    return chunks.slice(node.range[0], node.range[1]).join('');
  }

  function update(node, s) {
    chunks[node.range[0]] = s;
    const results = [];

    for (let i = node.range[0] + 1; i < node.range[1]; i++) {
      results.push(chunks[i] = '');
    }
    return results;
  }

  const globalScope = {
    vars: Object.create(null)
  };

  const functions = [];

  walk.simple(ast, {
    ScopeBody(node, scope) {
      node.scope = scope;
    },

    Function(node) {
      functions.push(node);
    }
  }, walk.scopeVisitor, globalScope);

  functions.forEach((f) => {
    if (f.type === 'FunctionExpression') {
      const paramNames = _.pluck(f.params, 'name');

      let generatedFunctionName = '_f';
      let i = 1;

      while (_.contains(paramNames, generatedFunctionName)) {
        generatedFunctionName = '_f' + i++;
      }
      update(f, `(function(unbound) {var ${generatedFunctionName} = _capture_context(unbound);var bound = function(${paramNames.join(', ')}) {return ${generatedFunctionName}.apply(this, arguments);};bound._lead_unbound_fn = unbound;return bound;})(${source(f)})`);
    }
  });

  return {
    global_vars: Object.keys(globalScope.vars),
    source: chunks.join('')
  };
}
