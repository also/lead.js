import Bacon from 'bacon.model';
import CodeMirror from 'codemirror';

import 'codemirror/mode/javascript/javascript';
import 'codemirror/mode/coffeescript/coffeescript';
import 'codemirror/addon/hint/show-hint';

import {suggest} from './autocomplete';

import * as Notebook from '../notebook';

let userNotebookKeymap = null;

function updateUserKeymap(keymap) {
  for (const k in userNotebookKeymap) {
    delete userNotebookKeymap[k];
  }

  if (keymap != null) {
    return Object.assign(userNotebookKeymap, keymap);
  }
}

function initUserKeymap() {
  // TODO resolve circular imports
  const Settings = require('../settings');

  if (userNotebookKeymap == null) {
    userNotebookKeymap = {};
    Settings.user_settings.toProperty('editor', 'keymap', 'notebook').onValue(updateUserKeymap);
  }
  return userNotebookKeymap;
}

export function create_editor(keyMap) {
  if (keyMap == null) {
    keyMap = 'notebook';
  }

  function target() {}

  if (!process.browser) {
    return CodeMirror(target);
  }

  const cm = CodeMirror(target, {
    value: '',
    mode: 'coffeescript',
    keyMap,
    tabSize: 2,
    lineNumbers: true,
    viewportMargin: Infinity
  });

  if (keyMap === 'notebook') {
    cm.addKeyMap(initUserKeymap());
  }

  cm.setCursor({line: cm.lineCount() - 1});

  return cm;
}

export function set_value(cm, value) {
  cm.setValue(value);

  return cm.setCursor({line: cm.lineCount() - 1});
}

export function setMinHeight(cm, minHeight) {
  cm.display.scroller.style.minHeight = minHeight + 'px';
  return cm.refresh();
}

export function get_value(cm) {
  return cm.getValue();
}

export function as_event_stream(cm, eventName, transformer) {
  return Bacon.fromBinder((handler) => {
    cm.on(eventName, handler);
    return () => {
      return cm.off(eventName, handler);
    };
  }, transformer);
}

export function add_error_mark(cm, e) {
  let {first_line, first_column, last_line, last_column} = e.location;

  if (first_line === last_line && first_column === last_column) {
    const line = cm.getLine(first_line);
    if (last_column === line.length) {
      first_column -= 1;
    } else {
      last_column += 1;
    }
  }

  const mark = cm.markText({
    line: first_line,
    ch: first_column
  }, {
    line: last_line,
    ch: last_column
  }, {
    className: 'error'
  });

  for (let l = first_line; l <= last_line; l++) {
    const gutter = document.createElement('div');

    gutter.title = e.message;
    gutter.innerHTML = '&nbsp;';
    gutter.className = 'errorMarker';

    // TODO make this less annoying, enable it
    // cm.setGutterMarker(l, 'error', gutter)
  }

  return mark;
}

function cmd(doc, fn) {
  fn.doc = doc;
  return fn;
}

export const commands = {
  ctx_run: cmd('Runs the contents of the cell', (cm) => {
    return cm.run();
  }),

  nb_run: cmd('Runs the contents of the cell and advances the cursor to the next cell', (cm) => {
    return Notebook.run(cm.lead_cell, {
      advance: true
    });
  }),

  nb_run_in_place: cmd('Runs the contents of the cell and keeps the cursor in the cell', (cm) => {
    return Notebook.run(cm.lead_cell, {
      advance: false
    });
  }),

  context_help: cmd('Shows help for the token under the cursor', (cm) => {
    const cur = cm.getCursor();
    const token = cm.getTokenAt(cur);

    return Notebook.context_help(cm.lead_cell, token.string);
  }),

  suggest: cmd('Suggests a function or metric', (cm) => {
    return CodeMirror.showHint(cm, suggest, {async: true});
  }),

  fill_with_last_value: cmd('Replaces the cell with the contents of the previous cell', (cm) => {
    const cell = Notebook.input_cell_at_offset(cm.lead_cell, -1);

    if (cell != null) {
      return set_value(cm, Notebook.cell_value(cell));
    } else {
      return CodeMirror.Pass;
    }
  }),

  next_cell: cmd('Moves the cursor to the next cell', (cm) => {
    if (!Notebook.move_focus(cm.lead_cell, 1)) {
      return CodeMirror.Pass;
    }
  }),

  previous_cell: cmd('Moves the cursor to the previous cell', (cm) => {
    if (!Notebook.move_focus(cm.lead_cell, -1)) {
      return CodeMirror.Pass;
    }
  }),

  maybe_next_cell: cmd('Moves the cursor to the next cell if the cursor is at the end', (cm) => {
    const cur = cm.getCursor();

    if (cur.line === cm.lineCount() - 1) {
      return commands.next_cell(cm);
    } else {
      return CodeMirror.Pass;
    }
  }),

  maybe_previous_cell: cmd('Moves the cursor to the next cell if the cursor is at the end', (cm) => {
    const cur = cm.getCursor();

    if (cur.line === 0) {
      return commands.previous_cell(cm);
    } else {
      return CodeMirror.Pass;
    }
  }),

  save(cm) {
    return Notebook.save(cm.lead_cell);
  }
};

const leadKeyMap = {
  Tab(cm) {
    if (cm.somethingSelected()) {
      return cm.indentSelection('add');
    } else {
      const spaces = Array(cm.getOption('indentUnit') + 1).join(' ');

      return cm.replaceSelection(spaces, 'end', '+input');
    }
  },
  'Shift-Tab': 'indentLess',
  fallthrough: ['default']
};

const contextKeyMap = {
  'Shift-Enter': 'ctx_run',
  'Ctrl-Enter': 'ctx_run',
  'Ctrl-Space': 'suggest',
  fallthrough: ['lead']
};

const notebookKeyMap = {
  Up: 'maybe_previous_cell',
  Down: 'maybe_next_cell',
  'Shift-Enter': 'nb_run',
  'Ctrl-Enter': 'nb_run_in_place',
  F1: 'context_help',
  'Ctrl-Space': 'suggest',
  fallthrough: ['lead']
};

if (process.browser) {
  CodeMirror.keyMap.notebook = notebookKeyMap;
  CodeMirror.keyMap.context = contextKeyMap;
  CodeMirror.keyMap.lead = leadKeyMap;
  Object.assign(CodeMirror.commands, commands);
}
