import React from 'react/addons';
import {connect} from 'react-redux';

import InputOutputComponent from './InputOutputComponent';


function mapStateToProps(state, ownProps) {
  const cellsById = state.get('cellsById');
  const {notebookId} = ownProps;
  return {
    cells: state.getIn(['notebooksById', notebookId, 'cells']).map(cellsById.get.bind(cellsById)),
    settings: state.get('settings')
  };
}

export default connect(mapStateToProps)(React.createClass({
  render() {
    const {settings={layout: 'repl'}, cells} = this.props;
    const {layout} = settings;
    const useMinHeight = layout === 'two-column';

    const ios = [];
    let props = null;
    cells.forEach((cell) => {
      if (cell.type === 'input') {
        props = {
          input_cell: cell,
          key: cell.key,
          useMinHeight: useMinHeight
        };
        ios.push(props);
      } else {
        if (props == null || props.input_cell.output_cell && props.input_cell.output_cell.key !== cell.key) {
          ios.push({
            output_cell: cell,
            key: cell.key,
            useMinHeight: useMinHeight
          });
        } else {
          props.output_cell = cell;
        }
        props = null;
      }
    });

    return (
      <div className={`notebook ${layout}-style`}>
        {ios.map((io) => <InputOutputComponent {...io}/>)}
      </div>
    );
  }
}));
