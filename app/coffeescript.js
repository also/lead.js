import CoffeeScript from 'coffee-script';
import * as Editor from './editor';
import * as Context from './context';
import * as Builtins from './builtins';
import React from 'react';
import {ToggleComponent, SourceComponent} from './components';
import _ from 'underscore';
import {logError, errorInfo} from './core';
import * as Javascript from './javascript';

if (process.browser) {
  const Scope = CoffeeScript.require('./scope').Scope;

  const freeVariable = Scope.prototype.freeVariable;

  Scope.prototype.freeVariable = function (name, reserve) {
    return freeVariable.call(this, 'LEAD_COFFEESCRIPT_FREE_VARIABLE_' + name, reserve);
  };
}

const CoffeeScriptErrorComponent = React.createClass({
  render() {
    const {error, compiled} = this.props;
    const info = errorInfo(error);
    const title = <pre>{info.message}</pre>;

    return (
      <div className='error'>
        {info.trace ? <ToggleComponent title={title}><pre>{info.trace.join('\n')}</pre></ToggleComponent> : title}
        <ToggleComponent title='Compiled JavaScript'>
          <SourceComponent language='javascript' value={compiled}/>
        </ToggleComponent>
      </div>
    );
  }
})

export function recompile(error_marks, editor) {
  error_marks.forEach((m) => m.clear());

  editor.clearGutter('error');
  try {
    CoffeeScript.compile(Editor.get_value(editor));
    return [];
  } catch (e) {
    return [Editor.add_error_mark(editor, e)];
  }
}

// gets the function for a cell
// TODO rename
export function get_fn(run_context) {
  return create_fn(Editor.get_value(run_context.input_cell.editor));
}

let fnNumber = 1;

// create the function for a string
// this is exposed for cases where there is no input cell
export function create_fn(string) {
  return (ctx) => {
    let compiled;
    try {
      const locals = Object.keys(ctx.scripting.replVars);

      compiled = CoffeeScript.compile(string, {bare: true, locals: locals}) + (`\n//# sourceURL=console-coffeescript-${fnNumber++}.js`);
      const {global_vars, source} = Javascript.mangle(compiled);

      return Context.scoped_eval(ctx, source, _.reject(global_vars, (name) => {
        return name.indexOf('_LEAD_COFFEESCRIPT_FREE_VARIABLE_') === 0;
      }));
    } catch (e) {
      if (e instanceof SyntaxError) {
        let details;
        if (e.location != null) {
          details = ` at ${e.location.first_line + 1}:${e.location.first_column + 1}`;
        } else {
          details = '';
        }
        Context.add_component(ctx, <Builtins.ErrorComponent message={`Syntax Error: ${e.message}${details}`}/>);
      } else {
        logError('Exception in CoffeeScript cell', e);

        Context.add_component(ctx, <CoffeeScriptErrorComponent error={e} compiled={compiled}/>);
      }
    }
    return Context.IGNORE;
  };
}
