import * as React from 'react';

import AppAwareMixin from '../appAwareMixin';
import * as Notebook from '../notebook';
import * as Context from '../context';
import * as GitHub from '../github';


export default React.createClass({
  displayName: 'GitHubNotebookComponent',
  mixins: [AppAwareMixin],

  initNotebook(nb) {
    const file = this.props.params.splat;

    Notebook.run_without_input_cell(nb, null, (ctx) => {
      GitHub.contextExports.load.fn(ctx, file, {
        run: true
      });
      return Context.IGNORE;
    });
    Notebook.focus_cell(Notebook.add_input_cell(nb));
  },

  render() {
    const {imports, modules} = this.context.app;

    return <Notebook.NotebookComponent
      context={{app: this.context.app}}
      init={this.initNotebook}
      {...{imports, modules}}/>;
  }
});
