import * as React from 'react';

import SingleCoffeeScriptCellNotebookComponent from './singleCoffeeScriptCellNotebookComponent';
import * as Settings from '../settings';
import AppAwareMixin from '../appAwareMixin';
import * as Notebook from '../notebook';


export default React.createClass({
  displayName: 'NewNotebookComponent',
  mixins: [AppAwareMixin],

  render() {
    const {imports, modules} = this.context.app;
    const introCommand = Settings.get('app', 'intro_command');

    if (introCommand && introCommand !== '') {
      return <SingleCoffeeScriptCellNotebookComponent value={introCommand}/>;
    } else {
      return <Notebook.NotebookComponent
        context={{app: this.context.app}}
        init={(nb) => Notebook.focus_cell(Notebook.add_input_cell(nb))}
        {...{imports, modules}}/>;
    }
  }
});
