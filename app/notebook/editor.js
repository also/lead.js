import CodeMirror from 'codemirror';

import * as Notebook from '../notebook';
import {cmd, set_value} from '../editor';


const keyMap = {
  Up: 'maybe_previous_cell',
  Down: 'maybe_next_cell',
  'Shift-Enter': 'nb_run',
  'Ctrl-Enter': 'nb_run_in_place',
  F1: 'context_help',
  'Ctrl-Space': 'suggest',
  fallthrough: ['lead']
};

const commands = {
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

if (process.browser) {
  CodeMirror.keyMap.notebook = keyMap;
  Object.assign(CodeMirror.commands, commands);
}
