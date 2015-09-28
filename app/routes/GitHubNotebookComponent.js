import * as React from 'react';

import AppAwareMixin from '../AppAwareMixin';
import * as Notebook from '../notebook';
import NotebookComponent from '../notebook/NotebookComponent';
import * as Context from '../context';
import * as GitHub from '../github';
import {replaceOnPropChange} from '../component-utils';


export default replaceOnPropChange(React.createClass({
  displayName: 'GitHubNotebookComponent',
  mixins: [AppAwareMixin],

  initNotebook(ctx) {
    const file = this.props.params.splat;

    Notebook.runWithoutInputCell(ctx, undefined, (ctx) => {
      GitHub.contextExports.load.fn(ctx, file, {run: true});
      return Context.IGNORE;
    });
    Notebook.focusCell(Notebook.addInputCell(ctx));
  },

  render() {
    const {imports, modules} = this.context.app;

    return <NotebookComponent
      context={{app: this.context.app}}
      init={this.initNotebook}
      {...{imports, modules}}/>;
  }
}));
