import * as React from 'react';

import SingleCoffeeScriptCellNotebookComponent from './SingleCoffeeScriptCellNotebookComponent';
import * as Settings from '../settings';
import AppAwareMixin from '../AppAwareMixin';
import * as Notebook from '../notebook';
import NotebookComponent from '../notebook/NotebookComponent';


export default React.createClass({
  displayName: 'NewNotebookComponent',
  mixins: [AppAwareMixin],

  render() {
    const {imports, modules} = this.context.app;
    const introCommand = Settings.get('app', 'intro_command');

    if (introCommand && introCommand !== '') {
      return <SingleCoffeeScriptCellNotebookComponent value={introCommand}/>;
    } else {
      return <NotebookComponent
        context={{app: this.context.app}}
        init={(ctx) => Notebook.focusCell(Notebook.addInputCell(ctx))}
        {...{imports, modules}}/>;
    }
  }
});
