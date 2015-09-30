import * as React from 'react';

import * as Notebook from '../notebook';
import NotebookComponent from '../notebook/NotebookComponent';
import {replaceOnPropChange} from '../component-utils';


export default replaceOnPropChange(React.createClass({
  initNotebook(ctx) {
    const {value} = this.props;
    const firstCell = Notebook.addInputCell(ctx);

    Notebook.setCellValue(ctx, firstCell, value);
    Notebook.run(ctx, firstCell);
  },

  render() {
    return <NotebookComponent init={this.initNotebook}/>;
  }
}));
