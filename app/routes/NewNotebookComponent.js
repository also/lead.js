import * as React from 'react';

import SingleCoffeeScriptCellNotebookComponent from './SingleCoffeeScriptCellNotebookComponent';
import * as Settings from '../settings';
import * as Notebook from '../notebook';
import NotebookComponent from '../notebook/NotebookComponent';


export default React.createClass({
  render() {
    const introCommand = Settings.get('app', 'intro_command');

    if (introCommand && introCommand !== '') {
      return <SingleCoffeeScriptCellNotebookComponent value={introCommand}/>;
    } else {
      return <NotebookComponent
        init={(ctx) => Notebook.focusCell(Notebook.addInputCell(ctx))}/>;
    }
  }
});
