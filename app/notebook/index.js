/* eslint-disable camelcase */

import _ from 'underscore';
import URI from 'URIjs';
import Bacon from 'bacon.model';
import * as Editor from '../editor';
import * as http from '../http';
import * as Context from '../context';
import * as Modules from '../modules';
import CoffeeScriptCell from '../coffeescript_cell';
import Markdown from '../markdown';
import * as Builtins from '../builtins';
import * as Documentation from '../documentation';
import NotebookComponent from './NotebookComponent';
import InputCellComponent from './InputCellComponent';
import OutputCellComponent from './OutputCellComponent';

export {NotebookComponent};

const contentType = 'application/x-lead-notebook';
const forwards = +1;
const backwards = -1;
let cellKey = 0;

function isInput(cell) {
  return cell.type === 'input';
}

function isClean(cell) {
  return Editor.get_value(cell.editor) === '' && !cell.used;
}

function visible(cell) {
  return cell.visible;
}

function identity(cell) {
  return cell;
}

function exportNotebook(notebook, currentCell) {
  return {
    lead_js_version: 0,
    cells: notebook.cells.filter(cell => cell !== currentCell && isInput(cell))
      .map(cell => ({type: 'input', value: Editor.get_value(cell.editor)}))
  };
}

function importNotebook(notebook, cell, imported, options) {
  const cells = _.map(imported.cells, importedCell => {
    if (importedCell.type === 'input') {
      cell = add_input_cell(notebook, {after: cell});
      set_cell_value(cell, importedCell.value);
      return cell;
    }
  });

  if (options.run) {
    _.each(cells, run);
  }

  return notebook;
}

function updateView(notebook) {
  return notebook.cells_model.set(notebook.cells.slice());
}

export function focus_cell(cell) {
  // hack around not understanding how this plays with react
  // https://github.com/facebook/react/issues/1791
  setTimeout(function () {
    cell.editor.focus();
    cell.notebook.cell_focused.push(cell);
  }, 0);
}

function clearNotebook(notebook) {
  notebook.cells.forEach(cell => cell.active = false);
  notebook.cells.length = 0;
  focus_cell(add_input_cell(notebook));
}

function cellIndex(cell) {
  return cell.notebook.cells.indexOf(cell);
}

function seek(startCell, direction, predicate=identity) {
  const {notebook} = startCell;
  let index = cellIndex(startCell) + direction;

  while (true) {
    const cell = notebook.cells[index];

    if (cell == null || predicate(cell)) {
      return cell;
    }

    index += direction;
  }
}

export function input_cell_at_offset(cell, offset) {
  return seek(cell, offset, isInput);
}

export function remove_cell(cell) {
  const index = cellIndex(cell);

  cell.notebook.cells.splice(index, 1);
  cell.active = false;
  updateView(cell.notebook);
}

function insertCell(cell, position={}) {
  let currentCell, offset;
  // TODO is it still possible to end up with cells that aren't active?
  if (position.before && position.before.active) {
    offset = 0;
    currentCell = position.before;
  } else if (position.after && position.after.active) {
    offset = 1;
    currentCell = position.after;
  } else {
    cell.notebook.cells.push(cell);
    updateView(cell.notebook);
    return;
  }

  const index = cellIndex(currentCell);

  currentCell.notebook.cells.splice(index + offset, 0, cell);
  updateView(cell.notebook);
}

export function add_input_cell(notebook, opts={}) {
  let cell;

  if (opts.reuse) {
    if (opts.after != null) {
      cell = seek(opts.after, forwards, cell => {
        return isInput(cell) && visible(cell);
      });
    } else if (opts.before != null) {
      cell = seek(opts.before, backwards, cell => {
        return isInput(cell) && visible(cell);
      });
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
  const cell = {
    type: 'input',
    key: `input${cellKey++}`,
    visible: true,
    active: true,
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
  const number = notebook.output_number++;
  const cell = {
    component_model: new Bacon.Model(null),
    type: 'output',
    key: 'output' + cellKey++,
    visible: true,
    active: true,
    notebook: notebook,
    number: number
  };

  cell.component = OutputCellComponent;
  return cell;
}

function runInputCell(input_cell) {
  const output_cell = createOutputCell(input_cell.notebook);

  input_cell.used = true;
  if (input_cell.output_cell != null) {
    remove_cell(input_cell.output_cell);
  }
  input_cell.output_cell = output_cell;
  insertCell(output_cell, {
    after: input_cell
  });
  input_cell.number = input_cell.notebook.input_number++;
  input_cell.changes.push(input_cell);
  const run_context = Context.create_run_context([
    input_cell.notebook.context,
    input_cell.context,
    {input_cell, output_cell},
    createNotebookRunContext(input_cell)
  ]);
  const fn = CoffeeScriptCell.get_fn(run_context);

  runWithContext(run_context, fn);
  input_cell.notebook.cell_run.push(input_cell);
  return output_cell;
}

function runWithContext(ctx, fn) {
  const {output_cell, pending} = ctx;
  // pending is a property that has the initial value 0 and tracks the number of pending promises
  const hasPending = pending.map(n => n > 0);
  // a cell is "done enough" if there were no async tasks,
  // or when the first async task completes
  const noLongerPending = ctx.changes.skipWhile(hasPending);

  output_cell.done = noLongerPending.take(1).map(() => output_cell);
  Context.run_in_context(ctx, fn);
  output_cell.component_model.set(() => ctx.component);
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
      cell = add_input_cell(notebook, {after: this.output_cell});
      set_cell_value(cell, code);
      focus_cell(cell);
    },

    run(code) {
      cell = add_input_cell(notebook, {after: this.output_cell});
      set_cell_value(cell, code);
      runInputCell(cell);
    },

    previously_run() {
      return Editor.get_value(input_cell_at_offset(cell, -1).editor);
    },

    exportNotebook() {
      exportNotebook(notebook, cell);
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
      run_without_input_cell(ctx.notebook, {after: ctx.output_cell}, ctx => {
        Context.add_component(ctx, <Markdown.MarkdownComponent value={file.content} opts={{base_href: file.base_href}}/>);
        return Context.IGNORE;
      });
    } else {
      try {
        imported = JSON.parse(file.content);
      } catch (error) {
        Builtins.contextExports.error.fn(ctx, `File ${file.filename} isn't a lead.js notebook:\n${error}`);
      }
      const version = imported.lead_js_version;

      if (version == null) {
        Builtins.contextExports.error.fn(ctx, `File ${file.filename} isn't a lead.js notebook`);
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

function save(input_cell) {
  const text = JSON.stringify(exportNotebook(input_cell));
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
  run_without_input_cell(cell.notebook, {before: cell}, ctx => {
    exports.contextExports.save.fn(ctx);
    return Context.IGNORE;
  });
}

export function context_help(cell, token) {
  const key = Documentation.getKey(cell.context, token);

  run_without_input_cell(cell.notebook, {before: cell}, ctx => {
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
    const link = save(ctx.notebook, ctx.input_cell);

    return <a href={link.href}>Download Notebook</a>;
  });

  cmd('loadFile', 'Loads a notebook from a file', (ctx) => {
    openFilePicker(ctx);
  });

  componentFn('load', 'Loads a script from a URL', (ctx, url, options={}) => {
    const promise = http.execute_xhr(url, {dataType: 'text', type: 'get'})
    .fail(({statusText}) => {
      throw statusText;
    }).then(xhr => {
      handle_file(ctx, {
        filename: URI(url).filename(),
        type: xhr.getResponseHeader('content-type'),
        content: xhr.responseText
      }, options);
    });

    return (
      <Context.AsyncComponent promise={promise}>
        <Builtins.ComponentAndError promise={promise}>
          Loading {url}
        </Builtins.ComponentAndError>
        <Builtins.PromiseStatusComponent promise={promise} start_time={new Date()}/>
      </Context.AsyncComponent>
    );
  });

  cmd('clear', 'Clears the notebook', (ctx) => {
    clearNotebook(ctx.notebook);
  });
});
