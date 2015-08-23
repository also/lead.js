import * as React from 'react';

import AppAwareMixin from '../AppAwareMixin';
import * as Notebook from '../notebook';
import {replaceOnPropChange} from '../component-utils';


export default replaceOnPropChange(React.createClass({
  displayName: 'SingleCoffeeScriptCellNotebookComponent',
  mixins: [AppAwareMixin],

  initNotebook(nb) {
    const {value} = this.props;
    const firstCell = Notebook.add_input_cell(nb);

    Notebook.set_cell_value(firstCell, value);
    Notebook.run(firstCell);
  },

  render() {
    const {imports, modules} = this.context.app;

    return <Notebook.NotebookComponent context={{app: this.context.app}} {...{imports, modules}} init={this.initNotebook}/>;
  }
}));
