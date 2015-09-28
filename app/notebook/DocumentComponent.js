import React from 'react/addons';
import {connect} from 'react-redux';

import InputOutputComponent from './InputOutputComponent';
import ContextRegisteringMixin from '../context/ContextRegisteringMixin';


function mapStateToProps(state, ownProps) {
  const cellsById = state.get('cellsById');
  const {notebookId} = ownProps;
  return {
    cells: state.getIn(['notebooksById', notebookId, 'cells']).map(cellsById.get.bind(cellsById)),
    layout: state.getIn(['settings', 'notebook', 'layout'])
  };
}

export default connect(mapStateToProps)(React.createClass({
  mixins: [ContextRegisteringMixin],

  render() {
    const {layout='repl', cells} = this.props;
    const useMinHeight = layout === 'two-column';

    const ios = [];
    let props = null;
    cells.forEach((cell) => {
      if (cell.type === 'input') {
        props = {
          inputCell: cell,
          key: cell.key,
          useMinHeight: useMinHeight
        };
        ios.push(props);
      } else {
        if (props == null || props.inputCell.outputCell && props.inputCell.outputCell.key !== cell.key) {
          ios.push({
            outputCell: cell,
            key: cell.key,
            useMinHeight: useMinHeight
          });
        } else {
          props.outputCell = cell;
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
