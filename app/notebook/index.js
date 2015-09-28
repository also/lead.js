import React from 'react/addons';
import URI from 'urijs';
import * as Immutable from 'immutable';

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
  return new Notebook({
    notebookId: nextNotebookId++,
    ctx: Object.assign({}, opts.context, Context.create_base_context(opts))
  });
}

function exportNotebook(ctx, notebook, currentCell) {
  const state = ctx.app.store.getState();
  const cellsById = state.get('cellsById');
  return {
    lead_js_version: 0,
    cells: state.getIn(['notebooksById', notebook.notebookId, 'cells'])
      .map((cellId) => cellsById.get(cellId))
      .toJS()
      .filter((cell) => cell.cellId !== currentCell.cellId && isInput(cell))
      .map((cell) => ({type: 'input', value: Editor.get_value(cell.editor)}))
  };
}

function importNotebook(ctx, notebook, cell, imported, options) {
  const cells = imported.cells.map((importedCell) => {
    if (importedCell.type === 'input') {
      cell = add_input_cell(ctx, notebook, {after: cell});
      set_cell_value(ctx, cell, importedCell.value);
      return cell;
    }
  });

  if (options.run) {
    cells.forEach((cell) => run(ctx, cell));
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

function clearNotebook(ctx, notebook) {
  ctx.app.store.dispatch(actions.cellsReplaced(notebook.notebookId, new Immutable.List()));

  focus_cell(add_input_cell(ctx, notebook));
}

function cellIndex(ctx, cell) {
  return ctx.app.store.getState().getIn(['notebooksById', cell.notebookId, 'cells']).indexOf(cell.cellId);
}

function seek(ctx, startCell, direction, predicate=identity) {
  const {notebookId} = startCell;
  let index = cellIndex(ctx, startCell) + direction;

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
  const {notebookId} = cell;

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

  const index = cellIndex(ctx, currentCell);

  ctx.app.store.dispatch(actions.insertCell(notebookId, cell, index + offset));
}

export function add_input_cell(ctx, notebook, opts={}) {
  let cell;

  if (opts.reuse) {
    if (opts.after != null) {
      cell = seek(ctx, opts.after, forwards, isInput);
    } else if (opts.before != null) {
      cell = seek(ctx, opts.before, backwards, isInput);
    }
  }

  if (!(cell != null && isClean(cell))) {
    cell = createInputCell(notebook);
    insertCell(ctx, cell, opts);
  }

  return cell;
}

function createInputCell(notebook) {
  const editor = Editor.create_editor();
  const cellId = `input${cellKey++}`;
  const cell = {
    type: 'input',
    cellId,
    notebookId: notebook.notebookId,
    notebook: notebook,
    ctx: createInputContext(notebook),
    used: false,
    editor: editor,
    editor_changes: Editor.as_event_stream(editor, 'change')
  };

  editor.lead_cell = cell;
  editor.ctx = cell.ctx;
  cell.component = InputCellComponent;

  // scan changes for the side effect in recompile
  // we have to subscribe so that the events are sent
  cell.editor_changes.debounce(200).scan([], CoffeeScriptCell.recompile).onValue(function () {});
  return cell;
}

export function set_cell_value(ctx, cell, value) {
  Editor.set_value(cell.editor, value);
}

function createOutputCell(notebook) {
  const cellId = 'output' + cellKey++;
  return {
    type: 'output',
    cellId,
    notebookId: notebook.notebookId,
    notebook
  };
}

function runInputCell(ctx, {notebook, cellId}) {
  const inputCell = ctx.app.store.getState().getIn(['cellsById', cellId])
  const outputCell = createOutputCell(notebook);

  inputCell.used = true;
  if (inputCell.output_cell != null) {
    removeCell(ctx, inputCell.output_cell);
  }
  insertCell(ctx, outputCell, {after: inputCell});
  ctx.app.store.dispatch(actions.updateCell(cellId, {output_cell: outputCell}, true));
  const run_context = Context.createScriptExecutionContext([
    inputCell.ctx,
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
  ctx.app.store.dispatch(actions.updateCell(output_cell.cellId, {component: ctx.component}, true));
}

function createBareOutputCellAndContext(notebook) {
  const output_cell = createOutputCell(notebook);
  return Context.createScriptExecutionContext([
    createInputContext(notebook),
    {output_cell},
    createNotebookRunContext(output_cell)
  ]);
}

export function run_without_input_cell(ctx, notebook, position, fn) {
  const runContext = createBareOutputCellAndContext(notebook);

  insertCell(ctx, runContext.output_cell, position);
  runWithContext(runContext, fn);
}

function createInputContext(notebook) {
  return Context.createScriptStaticContext(notebook.ctx);
}

function createNotebookRunContext(cell) {
  const notebook = cell.notebook;

  return {
    notebook,

    set_code(code) {
      const cell = add_input_cell(this, notebook, {after: this.output_cell});
      set_cell_value(this, cell, code);
      focus_cell(cell);
    },

    run(code) {
      const cell = add_input_cell(this, notebook, {after: this.output_cell});
      set_cell_value(this, cell, code);
      runInputCell(this, cell);
    },

    previously_run() {
      return Editor.get_value(inputCellAtOffset(this, cell, -1).editor);
    },

    exportNotebook() {
      return exportNotebook(this, notebook, cell);
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

export function handle_file(ctx, file, options={}) {
  let imported;
  if (file.type.indexOf('image') < 0) {
    const extension = file.filename.split('.').pop();

    if (extension === 'coffee') {
      const cell = add_input_cell(ctx, ctx.notebook, {after: ctx.output_cell});

      set_cell_value(ctx, cell, file.content);
      if (options.run) {
        runInputCell(ctx, cell);
      }
    } else if (extension === 'md') {
      run_without_input_cell(ctx, ctx.notebook, {after: ctx.output_cell}, (ctx) => {
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

      importNotebook(ctx, ctx.notebook, ctx.output_cell, imported, options);
    }
  }
}

function loadFile(ctx, file) {
  if (file.type.indexOf('image') < 0) {
    const reader = new FileReader();

    reader.onload = function (e) {
      handle_file(ctx, {
        filename: file.name,
        content: e.target.result,
        type: file.type
      });
    };
    reader.readAsText(file);
  }
}

// TODO rename
function doSave(ctx, notebook, fromInputCell) {
  const text = JSON.stringify(exportNotebook(ctx, notebook, fromInputCell));
  const blob = new Blob([text], {type: contentType});
  const link = document.createElement('a');

  link.href = window.webkitURL.createObjectURL(blob);
  link.download = 'notebook.lnb';
  link.click();
  return link;
}

export function run(ctx, cell, opts={advance: true}) {
  const output_cell = runInputCell(ctx, cell);

  if (opts.advance) {
    const new_cell = add_input_cell(ctx, cell.notebook, {after: output_cell, reuse: true});

    return focus_cell(new_cell);
  }
}

export function save(ctx, cell) {
  run_without_input_cell(ctx, cell.notebook, {before: cell}, (ctx) => {
    exports.contextExports.save.fn(ctx);
    return Context.IGNORE;
  });
}

export function context_help(ctx, cell, token) {
  const key = Documentation.getKey(cell.ctx, token);

  run_without_input_cell(ctx, cell.notebook, {before: cell}, (ctx) => {
    if (key != null) {
      Context.add_component(ctx, Builtins.help_component(ctx, Documentation.keyToString(key)));
    }

    return Context.IGNORE;
  });
}

export function move_focus(ctx, cell, offset) {
  const new_cell = inputCellAtOffset(ctx, cell, offset);

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
    const link = doSave(ctx, ctx.notebook, ctx.input_cell);

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
    clearNotebook(ctx, ctx.notebook);
  });
});
