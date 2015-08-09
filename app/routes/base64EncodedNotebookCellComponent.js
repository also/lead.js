import * as React from 'react';

import SingleCoffeeScriptCellNotebookComponent from './singleCoffeeScriptCellNotebookComponent';


export default React.createClass({
  displayName: 'Base64EncodedNotebookCellComponent',
  render() {
    const value = decodeURIComponent(escape(atob(this.props.params.splat)));

    return <SingleCoffeeScriptCellNotebookComponent value={value}/>;
  }
});
