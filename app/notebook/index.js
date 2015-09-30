import React from 'react/addons';
import URI from 'urijs';
import * as Immutable from 'immutable';

import * as Editor from '../editor';
import * as http from '../http';
import * as Context from '../context';
import AsyncComponent from '../context/AsyncComponent';
import * as Modules from '../modules';
import * as CoffeeScriptCell from '../scripting/coffeescript';
import MarkdownComponent from '../markdown/MarkdownComponent';
import * as Builtins from '../builtins';
import * as Documentation from '../documentation';
import InputCellComponent from './InputCellComponent';
import * as actions from './actions';
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

const Notebook = new Immutable.Record({
  notebookId: null,
  cells: new Immutable.List(),
  inputNumber: 0,
  outputNumber: 0,
  ctx: null
});

export function createNotebook(opts) {
  const notebookId = nextNotebookId++;
  const ctx = Object.assign({}, opts.context, Context.create_base_context(opts), {notebookId});
  return new Notebook({notebookId, ctx});
}

function exportNotebook(ctx, currentCellId) {
  const state = ctx.app.store.getState();
  const cellsById = state.get('cellsById');
  return {
    lead_js_version: 0,
    cells: state.getIn(['notebooksById', ctx.notebookId, 'cells'])
      .map((cellId) => cellsById.get(cellId))
      .toJS()
      .filter((cell) => cell.cellId !== currentCellId && isInput(cell))
      .map((cell) => ({type: 'input', value: Editor.get_value(cell.editor)}))
  };
}

function importNotebook(ctx, cell, imported, options) {
  const cells = imported.cells.map((importedCell) => {
    if (importedCell.type === 'input') {
      cell = addInputCell(ctx, {after: cell});
      setCellValue(ctx, cell, importedCell.value);
      return cell;
    }
  });

  if (options.run) {
    cells.forEach((cell) => run(ctx, cell));
  }
}

export function focusCell(cell) {
  // hack around not understanding how this plays with react
  // https://github.com/facebook/react/issues/1791
  setTimeout(function () {
    cell.editor.focus();
  }, 0);
}

function clearNotebook(ctx) {
  ctx.app.store.dispatch(actions.cellsReplaced(ctx.notebookId, new Immutable.List()));

  focusCell(addInputCell(ctx));
}

function cellIndex(ctx, cellId) {
  return ctx.app.store.getState().getIn(['notebooksById', ctx.notebookId, 'cells']).indexOf(cellId);
}

function seek(ctx, startCell, direction, predicate=identity) {
  const {notebookId} = ctx;
  let index = cellIndex(ctx, startCell.cellId) + direction;

  const state = ctx.app.store.getState();
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

function inputCellAtOffset(ctx, cell, offset) {
  return seek(ctx, cell, offset, isInput);
}

function removeCell(ctx, cell) {
  ctx.app.store.dispatch(actions.removeCell(cell.notebookId, cell.cellId));
}

function insertCell(ctx, cell, position={}) {
  const {notebookId} = ctx;

  let currentCell, offset;
  if (position.before) {
    offset = 0;
    currentCell = position.before;
  } else if (position.after) {
    offset = 1;
    currentCell = position.after;
  } else {
    ctx.app.store.dispatch(actions.insertCell(notebookId, cell));
    return;
  }

  const index = cellIndex(ctx, currentCell.cellId);

  ctx.app.store.dispatch(actions.insertCell(notebookId, cell, index + offset));
}

export function addInputCell(ctx, opts={}) {
  let cell;

  if (opts.reuse) {
    if (opts.after != null) {
      cell = seek(ctx, opts.after, forwards, isInput);
    } else if (opts.before != null) {
      cell = seek(ctx, opts.before, backwards, isInput);
    }
  }

  if (!(cell != null && isClean(cell))) {
    cell = createInputCell(ctx);
    insertCell(ctx, cell, opts);
  }

  return cell;
}

function createInputCell(ctx) {
  const {notebookId} = ctx;
  const notebook = ctx.app.store.getState().getIn(['notebooksById', notebookId]);
  const editor = Editor.create_editor();
  const cellId = `input${cellKey++}`;
  const cell = {
    type: 'input',
    cellId,
    notebookId,
    ctx: createInputContext(notebook.ctx),
    used: false,
    editor: editor,
    editorChanges: Editor.as_event_stream(editor, 'change')
  };

  editor.lead_cell = cell;
  editor.ctx = cell.ctx;
  cell.component = InputCellComponent;

  // scan changes for the side effect in recompile
  // we have to subscribe so that the events are sent
  cell.editorChanges.debounce(200).scan([], CoffeeScriptCell.recompile).onValue(function () {});
  return cell;
}

export function setCellValue(ctx, cell, value) {
  Editor.set_value(cell.editor, value);
}

function createOutputCell(notebookId) {
  const cellId = 'output' + cellKey++;
  return {
    type: 'output',
    cellId,
    notebookId
  };
}

function runInputCell(ctx, {cellId}) {
  const state = ctx.app.store.getState();
  const inputCell = state.getIn(['cellsById', cellId])
  const outputCell = createOutputCell(ctx.notebookId);

  inputCell.used = true;
  if (inputCell.outputCell != null) {
    removeCell(ctx, inputCell.outputCell);
  }
  insertCell(ctx, outputCell, {after: inputCell});
  ctx.app.store.dispatch(actions.updateCell(cellId, {outputCell}, true));
  const scriptExecutionContext = Context.createScriptExecutionContext([
    inputCell.ctx,
    {inputCell, outputCell},
    createNotebookRunContext(inputCell)
  ]);
  const fn = CoffeeScriptCell.get_fn(scriptExecutionContext);

  runWithContext(scriptExecutionContext, fn);
  return outputCell;
}

// TODO rename: runs in a ctx with an outputCell
function runWithContext(ctx, fn) {
  const {outputCell, pending} = ctx;
  // pending is a property that has the initial value 0 and tracks the number of pending promises
  const hasPending = pending.map((n) => n > 0);
  // a cell is "done enough" if there were no async tasks,
  // or when the first async task completes
  const noLongerPending = ctx.changes.skipWhile(hasPending);

  outputCell.done = noLongerPending.take(1).map(() => outputCell);
  Context.run_in_context(ctx, fn);
  ctx.app.store.dispatch(actions.updateCell(outputCell.cellId, {component: ctx.component}, true));
}

export function runWithoutInputCell(ctx, position, fn) {
  const notebook = ctx.app.store.getState().getIn(['notebooksById', ctx.notebookId]);
  const outputCell = createOutputCell(ctx.notebookId);
  const scriptExecutionContext = Context.createScriptExecutionContext([
    createInputContext(notebook.ctx),
    {outputCell},
    createNotebookRunContext(outputCell)
  ]);

  insertCell(ctx, outputCell, position);
  runWithContext(scriptExecutionContext, fn);
}

function createInputContext(ctx) {
  return Context.createScriptStaticContext(ctx);
}

function createNotebookRunContext(cell) {
  return {
    addScript(code) {
      const cell = addInputCell(this, {after: this.outputCell});
      setCellValue(this, cell, code);
      focusCell(cell);
    },

    runScript(code) {
      const cell = addInputCell(this, {after: this.outputCell});
      setCellValue(this, cell, code);
      runInputCell(this, cell);
    },

    previously_run() {
      return Editor.get_value(inputCellAtOffset(this, cell, -1).editor);
    },

    exportNotebook() {
      return exportNotebook(this, cell.cellId);
    }
  };
}

function openFilePicker(run_context) {
  const inputElt = document.createElement('input');

  inputElt.type = 'file';
  inputElt.onchange = function (e) {
    Array.from(e.target.files).forEach((file) => {
      loadFile(run_context, file)
    });
  };
  inputElt.dispatchEvent(new Event('click'));
}

export function handleFile(ctx, file, options={}) {
  let imported;
  if (file.type.indexOf('image') < 0) {
    const extension = file.filename.split('.').pop();

    if (extension === 'coffee') {
      const cell = addInputCell(ctx, {after: ctx.outputCell});

      setCellValue(ctx, cell, file.content);
      if (options.run) {
        runInputCell(ctx, cell);
      }
    } else if (extension === 'md') {
      runWithoutInputCell(ctx, {after: ctx.outputCell}, (ctx) => {
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

      importNotebook(ctx, ctx.outputCell, imported, options);
    }
  }
}

function loadFile(ctx, file) {
  if (file.type.indexOf('image') < 0) {
    const reader = new FileReader();

    reader.onload = function (e) {
      handleFile(ctx, {
        filename: file.name,
        content: e.target.result,
        type: file.type
      });
    };
    reader.readAsText(file);
  }
}

// TODO rename
function doSave(ctx, currentCellId) {
  const text = JSON.stringify(exportNotebook(ctx, currentCellId));
  const blob = new Blob([text], {type: contentType});
  const link = document.createElement('a');

  link.href = window.webkitURL.createObjectURL(blob);
  link.download = 'notebook.lnb';
  link.click();
  return link;
}

export function run(ctx, cell, opts={advance: true}) {
  const outputCell = runInputCell(ctx, cell);

  if (opts.advance) {
    const newCell = addInputCell(ctx, {after: outputCell, reuse: true});

    return focusCell(newCell);
  }
}

export function save(ctx, cell) {
  runWithoutInputCell(ctx, {before: cell}, (ctx) => {
    exports.scriptingExports.save.fn(ctx);
    return Context.IGNORE;
  });
}

export function contextHelp(ctx, cell, token) {
  const key = Documentation.getKey(cell.ctx, token);

  runWithoutInputCell(ctx, {before: cell}, (ctx) => {
    if (key != null) {
      Context.add_component(ctx, Builtins.help_component(ctx, Documentation.keyToString(key)));
    }

    return Context.IGNORE;
  });
}

export function moveFocus(ctx, cell, offset) {
  const offsetCell = inputCellAtOffset(ctx, cell, offset);

  if (offsetCell != null) {
    focusCell(offsetCell);
    return true;
  } else {
    return false;
  }
}

export function encodeNotebookValue(value) {
  return btoa(unescape(encodeURIComponent(value)));
}

Modules.export(exports, 'notebook', ({componentFn, cmd, componentCmd}) => {
  componentCmd('save', 'Saves the current notebook to a file', (ctx) => {
    const link = doSave(ctx, ctx.inputCell.cellId);

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
      handleFile(ctx, {
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
    clearNotebook(ctx);
  });
});
