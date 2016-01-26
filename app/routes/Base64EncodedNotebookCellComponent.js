import * as React from 'react';

import SingleCoffeeScriptCellNotebookComponent from './SingleCoffeeScriptCellNotebookComponent';


export default React.createClass({
  displayName: 'Base64EncodedNotebookCellComponent',
  render() {
    const value = decodeURIComponent(escape(atob(decodeURIComponent(this.props.params.splat))));

    return <SingleCoffeeScriptCellNotebookComponent value={value}/>;
  }
});
