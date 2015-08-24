import Bacon from 'bacon.model';
import CodeMirror from 'codemirror';

import 'codemirror/mode/javascript/javascript';
import 'codemirror/mode/coffeescript/coffeescript';
import 'codemirror/addon/hint/show-hint';

import {suggest} from './autocomplete';


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

export function cmd(doc, fn) {
  fn.doc = doc;
  return fn;
}

const commands = {
  ctx_run: cmd('Runs the contents of the cell', (cm) => {
    return cm.run();
  }),

  suggest: cmd('Suggests a function or metric', (cm) => {
    return CodeMirror.showHint(cm, suggest, {async: true});
  })
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

if (process.browser) {
  CodeMirror.keyMap.context = contextKeyMap;
  CodeMirror.keyMap.lead = leadKeyMap;
  Object.assign(CodeMirror.commands, commands);
}
