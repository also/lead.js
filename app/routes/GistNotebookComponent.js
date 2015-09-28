import * as React from 'react';

import AppAwareMixin from '../AppAwareMixin';
import * as Notebook from '../notebook';
import NotebookComponent from '../notebook/NotebookComponent';
import * as Context from '../context';
import * as GitHub from '../github';
import {replaceOnPropChange} from '../component-utils';


export default replaceOnPropChange(React.createClass({
  displayName: 'GistNotebookComponent',
  mixins: [AppAwareMixin],

  initNotebook(ctx, nb) {
    const gist = this.props.params.splat;
    Notebook.run_without_input_cell(ctx, nb, undefined, (ctx) => {
      GitHub.contextExports.gist.fn(ctx, gist, {run: true});
      return Context.IGNORE;
    });
    Notebook.focus_cell(Notebook.add_input_cell(ctx, nb));
  },

  render() {
    const {imports, modules} = this.context.app;

    return <NotebookComponent
      context={{app: this.context.app}}
      init={this.initNotebook}
      {...{imports, modules}}/>;
  }
}));
