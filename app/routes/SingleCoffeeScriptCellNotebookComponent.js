import * as React from 'react';

import AppAwareMixin from '../AppAwareMixin';
import * as Notebook from '../notebook';
import NotebookComponent from '../notebook/NotebookComponent';
import {replaceOnPropChange} from '../component-utils';


export default replaceOnPropChange(React.createClass({
  displayName: 'SingleCoffeeScriptCellNotebookComponent',
  mixins: [AppAwareMixin],

  initNotebook(ctx, nb) {
    const {value} = this.props;
    const firstCell = Notebook.add_input_cell(ctx, nb);

    Notebook.set_cell_value(ctx, firstCell, value);
    Notebook.run(ctx, firstCell);
  },

  render() {
    const {imports, modules} = this.context.app;

    return <NotebookComponent context={{app: this.context.app}} {...{imports, modules}} init={this.initNotebook}/>;
  }
}));
