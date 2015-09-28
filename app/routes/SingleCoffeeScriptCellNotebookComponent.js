import * as React from 'react';

import AppAwareMixin from '../AppAwareMixin';
import * as Notebook from '../notebook';
import NotebookComponent from '../notebook/NotebookComponent';
import {replaceOnPropChange} from '../component-utils';


export default replaceOnPropChange(React.createClass({
  displayName: 'SingleCoffeeScriptCellNotebookComponent',
  mixins: [AppAwareMixin],

  initNotebook(ctx) {
    const {value} = this.props;
    const firstCell = Notebook.addInputCell(ctx);

    Notebook.setCellValue(ctx, firstCell, value);
    Notebook.run(ctx, firstCell);
  },

  render() {
    const {imports, modules} = this.context.app;

    return <NotebookComponent context={{app: this.context.app}} {...{imports, modules}} init={this.initNotebook}/>;
  }
}));
