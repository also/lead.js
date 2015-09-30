import * as React from 'react';

import * as Notebook from '../notebook';
import NotebookComponent from '../notebook/NotebookComponent';
import * as Context from '../context';
import * as GitHub from '../github';
import {replaceOnPropChange} from '../component-utils';


export default replaceOnPropChange(React.createClass({
  initNotebook(ctx) {
    const file = this.props.params.splat;

    Notebook.runWithoutInputCell(ctx, undefined, (ctx) => {
      GitHub.scriptingExports.load.fn(ctx, file, {run: true});
      return Context.IGNORE;
    });
    Notebook.focusCell(Notebook.addInputCell(ctx));
  },

  render() {
    return <NotebookComponent init={this.initNotebook}/>;
  }
}));
