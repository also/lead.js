import * as Immutable from 'immutable';

import * as actionTypes from './actionTypes';


function cellsRemoved(cellsById, cellKeys) {
  const set = new Set(cellKeys);
  return cellsById.filterNot(({cellId}) => set.has(cellId));
}

const initialState = Immutable.fromJS({notebooksById: {}, cellsById: {}});

export default function reducer(state=initialState, action) {
  switch (action.type) {
  case actionTypes.NOTEBOOK_CREATED:
    return state.setIn(['notebooksById', action.notebook.notebookId], action.notebook);

  case actionTypes.NOTEBOOK_DESTROYED:
    const notebook = state.getIn(['notebooksById', action.notebookId]);
    return state.deleteIn(['notebooks', action.notebookId])
      .updateIn(['cellsById'], (cellsById) => cellsRemoved(cellsById, notebook.cells.map(({cellId}) => cellId)));

  case actionTypes.NOTEBOOK_CELLS_REPLACED:
    const currentCellKeys = state.getIn(['notebooksById', action.notebookId, 'cells']).map(({cellId}) => cellId);
    return state.setIn(['notebooksById', action.notebookId, 'cells'], action.cells.map(({cellId}) => cellId))
      .updateIn(['cellsById'], (cellsById) => {
        return cellsRemoved(cellsById, currentCellKeys)
          .merge(action.cells.map((cell) => [cell.cellId, cell]));
      });

  case actionTypes.INSERT_CELL:
    const {cell} = action;
    return state.updateIn(['notebooksById', action.notebookId, 'cells'], (cells) => {
      if (action.index) {
        return cells.splice(action.index, 0, cell.cellId);
      } else {
        return cells.push(cell.cellId);
      }
    }).setIn(['cellsById', cell.cellId], cell);

  case actionTypes.UPDATE_CELL:
    let updatedCell = state.getIn(['cellsById', action.cellId]);
    if (action.incrementNumber) {
      let number;
      return state.updateIn(['notebooksById', updatedCell.notebookId, `${updatedCell.type}Number`], (n) => number = n + 1)
        .setIn(['cellsById', action.cellId], Object.assign({}, updatedCell, action.update, {number}));
    } else {
      return state.setIn(['cellsById', action.cellId], Object.assign({}, updatedCell, action.update));
    }
    break;

  case actionTypes.REMOVE_CELL:
    return state.updateIn(['notebooksById', action.notebookId, 'cells'],
      (cells) => cells.filterNot((cellId) => cellId === action.cellId)
    ).deleteIn(['cellsById', action.cellId]);

  default:
    return state;
  }
}
