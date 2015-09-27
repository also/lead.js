import React from 'react/addons';
import URI from 'urijs';
import Bacon from 'bacon.model';
import * as Immutable from 'immutable';
import {createStore} from 'redux';

import * as Settings from '../settings';
import * as Editor from '../editor';
import * as http from '../http';
import * as Context from '../context';
import AsyncComponent from '../context/AsyncComponent';
import * as Modules from '../modules';
import * as CoffeeScriptCell from '../coffeescript';
import MarkdownComponent from '../markdown/MarkdownComponent';
import * as Builtins from '../builtins';
import * as Documentation from '../documentation';
import InputCellComponent from './InputCellComponent';
import './editor';


const contentType = 'application/x-lead-notebook';
const forwards = +1;
const backwards = -1;
let cellKey = 0;
let nextNotebookId = 0;

function isInput(cell) {
  return cell.type === 'input';
}

function isClean(cell) {
  return Editor.get_value(cell.editor) === '' && !cell.used;
}

function identity(cell) {
  return cell;
}

const actionTypes = {
  NOTEBOOK_CREATED: 'NOTEBOOK_CREATED',
  NOTEBOOK_DESTROYED: 'NOTEBOOK_DESTROYED',
  CELLS_REPLACED: 'CELLS_REPLACED',
  SETTINGS_CHANGED: 'SETTINGS_CHANGED',
  INSERT_CELL: 'INSERT_CELL',
  UPDATE_CELL: 'UPDATE_CELL',
  REMOVE_CELL_AT_INDEX: 'REMOVE_CELL_AT_INDEX'
};

export const actions = {
  notebookCreated(notebookId) {
    return {type: actionTypes.NOTEBOOK_CREATED, notebookId};
  },

  notebookDestroyed(notebookId) {
    return {type: actionTypes.NOTEBOOK_DESTROYED, notebookId};
  },

  cellsReplaced(notebookId, cells) {
    return {type: actionTypes.CELLS_REPLACED, notebookId, cells};
  },

  settingsChanged(settings) {
    return {type: actionTypes.SETTINGS_CHANGED, settings};
  },

  insertCell(notebookId, cell, index) {
    return {type: actionTypes.INSERT_CELL, notebookId, cell, index};
  },

  removeCellAtIndex(notebookId, index) {
    return {type: actionTypes.REMOVE_CELL_AT_INDEX, notebookId, index};
  },

  updateCell(cellId, update) {
    return {type: actionTypes.UPDATE_CELL, cellId, update};
  }
}

const Notebook = new Immutable.Record({cells: new Immutable.List(), inputNumber: 0, outputNumber: 0});

function cellsRemoved(cellsById, cellKeys) {
  const set = new Set(cellKeys);
  return cellsById.filterNot(({cellId}) => set.has(cellId));
}

const initialState = Immutable.fromJS({notebooksById: {}, cellsById: {}, settings: {}});

function reducer(state=initialState, action) {
  console.log('notebook action', action.type);
  switch (action.type) {
  case actionTypes.NOTEBOOK_CREATED:
    return state.setIn(['notebooksById', action.notebookId], new Notebook());

  case actionTypes.NOTEBOOK_DESTROYED:
    const notebook = state.getIn(['notebooksById', action.notebookId]);
    return state.deleteIn(['notebooks', action.notebookId])
      .updateIn(['cellsById'], (cellsById) => cellsRemoved(cellsById, notebook.cells.map(({cellId}) => cellId)));

  case actionTypes.CELLS_REPLACED:
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
    let updatedCell;
    return state.updateIn(['cellsById', action.cellId], (cell) => {
      updatedCell = cell;
      return Object.assign({}, cell, action.update);
    })
      .updateIn(['notebooksById', updatedCell.notebookId, `${updatedCell.type}Number`], (n) => updatedCell.number = n++);

  case actionTypes.REMOVE_CELL_AT_INDEX:
    let cellId;
    return state.updateIn(['notebooksById', action.notebookId, 'cells'], (cells) => {
      cellId = cells.get(action.index);
      return cells.delete(action.index);
    }).deleteIn(['cellsById', cellId]);

  case actionTypes.SETTINGS_CHANGED:
    return state.setIn(['settings'], action.settings);

  default:
    return state;
  }
}

const store = createStore(reducer);
Settings.toProperty('notebook').onValue((settings) => {
  store.dispatch(actions.settingsChanged(settings));
});

export function createNotebook(opts) {
  const notebook = {
    notebookId: nextNotebookId++,
    store,
    context: opts.context
  };

  store.dispatch(actions.notebookCreated(notebook.notebookId));

  // FIXME
  // if (process.browser) {
  //   const bodyElt = document.querySelector('.body');
  //   const scrolls = Bacon.fromEventTarget(bodyElt, 'scroll');
  //   const scroll_to = notebook.cell_run.flatMapLatest(function (input_cell) {
  //     return input_cell.output_cell.done.delay(0).takeUntil(scrolls);
  //   });
  //
  //   scroll_to.onValue(function (output_cell) {
  //     const bodyTop = bodyElt.getBoundingClientRect().top;
  //     const bodyScroll = bodyElt.scrollTop;
  //
  //     bodyElt.scrollTop = store.getState().getIn(['cellsById', output_cell.cellId]).dom_node.getBoundingClientRect().top - bodyTop + bodyScroll;
  //   });
  // }

  notebook.base_context = Context.create_base_context(opts);
  return notebook;
}

export function destroyNotebook(notebook) {
  notebook.store.dispatch(actions.notebookDestroyed(notebook.notebookId));
}

function exportNotebook(notebook, currentCell) {
  return {
    lead_js_version: 0,
    cells: notebook.store.getState().getIn(['notebooksById', notebook.notebookId, 'cells']).filter((cell) => cell !== currentCell && isInput(cell))
      .map((cell) => ({type: 'input', value: Editor.get_value(cell.editor)}))
  };
}

function importNotebook(notebook, cell, imported, options) {
  const cells = imported.cells.map((importedCell) => {
    if (importedCell.type === 'input') {
      cell = add_input_cell(notebook, {after: cell});
      set_cell_value(cell, importedCell.value);
      return cell;
    }
  });

  if (options.run) {
    cells.forEach(run);
  }

  return notebook;
}

export function focus_cell(cell) {
  // hack around not understanding how this plays with react
  // https://github.com/facebook/react/issues/1791
  setTimeout(function () {
    cell.editor.focus();
  }, 0);
}

function clearNotebook(notebook) {
  notebook.store.dispatch(actions.cellsReplaced(notebook.notebookId, new Immutable.List()));

  focus_cell(add_input_cell(notebook));
}

function cellIndex(cell) {
  return cell.notebook.store.getState().getIn(['notebooksById', cell.notebookId, 'cells']).indexOf(cell.cellId);
}

function seek(startCell, direction, predicate=identity) {
  const {notebook, notebookId} = startCell;
  let index = cellIndex(startCell) + direction;

  const state = notebook.store.getState();
  const cellsById = state.get('cellsById');
  const cells = state.getIn(['notebooksById', notebookId, 'cells']);

  while (true) {
    const cellId = cells.get(index);

    if (cellId == null) {
      return null;
    } else {
      const cell = cellsById.get(cellId);
      if (predicate(cell)) {
        return cell;
      }
    }

    index += direction;
  }
}

export function input_cell_at_offset(cell, offset) {
  return seek(cell, offset, isInput);
}

function remove_cell(cell) {
  const index = cellIndex(cell);

  cell.notebook.store.dispatch(actions.removeCellAtIndex(cell.notebookId, index));
}

function insertCell(cell, position={}) {
  const {notebook, notebookId} = cell;

  let currentCell, offset;
  if (position.before) {
    offset = 0;
    currentCell = position.before;
  } else if (position.after) {
    offset = 1;
    currentCell = position.after;
  } else {
    notebook.store.dispatch(actions.insertCell(notebookId, cell));
    return;
  }

  const index = cellIndex(currentCell);

  notebook.store.dispatch(actions.insertCell(notebookId, cell, index + offset));
}

export function add_input_cell(notebook, opts={}) {
  let cell;

  if (opts.reuse) {
    if (opts.after != null) {
      cell = seek(opts.after, forwards, isInput);
    } else if (opts.before != null) {
      cell = seek(opts.before, backwards, isInput);
    }
  }

  if (!(cell != null && isClean(cell))) {
    cell = createInputCell(notebook);
    insertCell(cell, opts);
  }

  return cell;
}

function createInputCell(notebook) {
  const editor = Editor.create_editor();
  const cellId = `input${cellKey++}`;
  const cell = {
    type: 'input',
    key: cellId,
    cellId,
    notebookId: notebook.notebookId,
    notebook: notebook,
    context: createInputContext(notebook),
    used: false,
    changes: new Bacon.Bus(),
    editor: editor,
    editor_changes: Editor.as_event_stream(editor, 'change')
  };

  editor.lead_cell = cell;
  editor.ctx = cell.context;
  cell.component = InputCellComponent;

  // scan changes for the side effect in recompile
  // we have to subscribe so that the events are sent
  cell.editor_changes.debounce(200).scan([], CoffeeScriptCell.recompile).onValue(function () {});
  return cell;
}

export function set_cell_value(cell, value) {
  Editor.set_value(cell.editor, value);
}

function createOutputCell(notebook) {
  const cellId = 'output' + cellKey++;
  return {
    type: 'output',
    key: cellId,
    cellId,
    notebookId: notebook.notebookId,
    notebook
  };
}

function runInputCell({notebook, cellId}) {
  const inputCell = notebook.store.getState().getIn(['cellsById', cellId])
  const outputCell = createOutputCell(notebook);

  inputCell.used = true;
  if (inputCell.output_cell != null) {
    remove_cell(inputCell.output_cell);
  }
  insertCell(outputCell, {after: inputCell});
  notebook.store.dispatch(actions.updateCell(cellId, {output_cell: outputCell}));
  const run_context = Context.create_run_context([
    inputCell.notebook.context,
    inputCell.context,
    {input_cell: inputCell, output_cell: outputCell},
    createNotebookRunContext(inputCell)
  ]);
  const fn = CoffeeScriptCell.get_fn(run_context);

  runWithContext(run_context, fn);
  return outputCell;
}

function runWithContext(ctx, fn) {
  const {output_cell, pending} = ctx;
  // pending is a property that has the initial value 0 and tracks the number of pending promises
  const hasPending = pending.map((n) => n > 0);
  // a cell is "done enough" if there were no async tasks,
  // or when the first async task completes
  const noLongerPending = ctx.changes.skipWhile(hasPending);

  output_cell.done = noLongerPending.take(1).map(() => output_cell);
  Context.run_in_context(ctx, fn);
  output_cell.notebook.store.dispatch(actions.updateCell(output_cell.cellId, {component: ctx.component}));
}

function createBareOutputCellAndContext(notebook) {
  const output_cell = createOutputCell(notebook);
  return Context.create_run_context([
    notebook.context,
    createInputContext(notebook),
    {output_cell},
    createNotebookRunContext(output_cell)
  ]);
}

export function run_without_input_cell(notebook, position, fn) {
  const runContext = createBareOutputCellAndContext(notebook);

  insertCell(runContext.output_cell, position);
  runWithContext(runContext, fn);
}

function createInputContext(notebook) {
  return Context.create_context(notebook.base_context);
}

function createNotebookRunContext(cell) {
  const notebook = cell.notebook;

  return {
    notebook,

    set_code(code) {
      const cell = add_input_cell(notebook, {after: this.output_cell});
      set_cell_value(cell, code);
      focus_cell(cell);
    },

    run(code) {
      const cell = add_input_cell(notebook, {after: this.output_cell});
      set_cell_value(cell, code);
      runInputCell(cell);
    },

    previously_run() {
      return Editor.get_value(input_cell_at_offset(cell, -1).editor);
    },

    exportNotebook() {
      return exportNotebook(notebook, cell);
    }
  };
}

function openFilePicker(run_context) {
  const inputElt = document.createElement('input');

  inputElt.type = 'file';
  inputElt.onchange = function (e) {
    let i, len;
    const ref = e.target.files;
    const results = [];

    for (i = 0, len = ref.length; i < len; i++) {
      const file = ref[i];

      results.push(loadFile(run_context, file));
    }
    return results;
  };
  return inputElt.dispatchEvent(new Event('click'));
}

export function handle_file(ctx, file, options={}) {
  let imported;
  if (file.type.indexOf('image') < 0) {
    const extension = file.filename.split('.').pop();

    if (extension === 'coffee') {
      const cell = add_input_cell(ctx.notebook, {after: ctx.output_cell});

      set_cell_value(cell, file.content);
      if (options.run) {
        return runInputCell(cell);
      }
    } else if (extension === 'md') {
      run_without_input_cell(ctx.notebook, {after: ctx.output_cell}, (ctx) => {
        Context.add_component(ctx, <MarkdownComponent value={file.content} opts={{base_href: file.base_href}}/>);
        return Context.IGNORE;
      });
    } else {
      try {
        imported = JSON.parse(file.content);
      } catch (error) {
        Context.add_component(ctx, <Builtins.ErrorComponent message={`File ${file.filename} isn't a lead.js notebook:\n${error}`}/>);
      }
      const version = imported.lead_js_version;

      if (version == null) {
        Context.add_component(ctx, <Builtins.ErrorComponent message={`File ${file.filename} isn't a lead.js notebook`}/>);
      }

      importNotebook(ctx.notebook, ctx.output_cell, imported, options);
    }
  }
}

function loadFile(ctx, file) {
  if (file.type.indexOf('image') < 0) {
    const reader = new FileReader();

    reader.onload = function (e) {
      return handle_file(ctx, {
        filename: file.name,
        content: e.target.result,
        type: file.type
      });
    };
    return reader.readAsText(file);
  }
}

// TODO rename
function doSave(fromInputCell) {
  const text = JSON.stringify(exportNotebook(fromInputCell));
  const blob = new Blob([text], {type: contentType});
  const link = document.createElement('a');

  link.href = window.webkitURL.createObjectURL(blob);
  link.download = 'notebook.lnb';
  link.click();
  return link;
}

export function run(cell, opts={advance: true}) {
  const output_cell = runInputCell(cell);

  if (opts.advance) {
    const new_cell = add_input_cell(cell.notebook, {after: output_cell, reuse: true});

    return focus_cell(new_cell);
  }
}

export function save(cell) {
  run_without_input_cell(cell.notebook, {before: cell}, (ctx) => {
    exports.contextExports.save.fn(ctx);
    return Context.IGNORE;
  });
}

export function context_help(cell, token) {
  const key = Documentation.getKey(cell.context, token);

  run_without_input_cell(cell.notebook, {before: cell}, (ctx) => {
    if (key != null) {
      Context.add_component(ctx, Builtins.help_component(ctx, Documentation.keyToString(key)));
    }

    return Context.IGNORE;
  });
}

export function move_focus(cell, offset) {
  const new_cell = input_cell_at_offset(cell, offset);

  if (new_cell != null) {
    focus_cell(new_cell);
    return true;
  } else {
    return false;
  }
}

export function cell_value(cell) {
  return cell.editor.getValue();
}

export function encodeNotebookValue(value) {
  return btoa(unescape(encodeURIComponent(value)));
}

Modules.export(exports, 'notebook', ({componentFn, cmd, componentCmd}) => {
  componentCmd('save', 'Saves the current notebook to a file', (ctx) => {
    const link = doSave(ctx.notebook, ctx.input_cell);

    return <a href={link.href}>Download Notebook</a>;
  });

  cmd('loadFile', 'Loads a notebook from a file', (ctx) => {
    openFilePicker(ctx);
  });

  componentFn('load', 'Loads a script from a URL', (ctx, url, options={}) => {
    const promise = http.execute_xhr(url, {dataType: 'text', type: 'get'})
    .fail(({statusText}) => {
      throw statusText;
    }).then((xhr) => {
      handle_file(ctx, {
        filename: new URI(url).filename(),
        type: xhr.getResponseHeader('content-type'),
        content: xhr.responseText
      }, options);
    });

    return (
      <AsyncComponent promise={promise}>
        <Builtins.ComponentAndError promise={promise}>
          Loading {url}
        </Builtins.ComponentAndError>
        <Builtins.PromiseStatusComponent promise={promise} start_time={new Date()}/>
      </AsyncComponent>
    );
  });

  cmd('clear', 'Clears the notebook', (ctx) => {
    clearNotebook(ctx.notebook);
  });
});
