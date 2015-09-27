import * as types from './actionTypes';


export function notebookCreated(notebook) {
  return {type: types.NOTEBOOK_CREATED, notebook};
}

export function notebookDestroyed(notebookId) {
  return {type: types.NOTEBOOK_DESTROYED, notebookId};
}

export function cellsReplaced(notebookId, cells) {
  return {type: types.NOTEBOOK_CELLS_REPLACED, notebookId, cells};
}

export function insertCell(notebookId, cell, index) {
  return {type: types.INSERT_CELL, notebookId, cell, index};
}

export function removeCellAtIndex(notebookId, index) {
  return {type: types.REMOVE_CELL_AT_INDEX, notebookId, index};
}

export function updateCell(cellId, update, incrementNumber) {
  return {type: types.UPDATE_CELL, cellId, update, incrementNumber};
}
