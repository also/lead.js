import CodeMirror from 'codemirror';
import _ from 'underscore';
import Q from 'q';
import * as Context from '../context';


function tokenAfter(cm, token, line) {
  let t = token;
  let last_interesting_token = null;

  while (true) {
    // TODO isn't this returning the *last* token?
    const next_token = cm.getTokenAt(CodeMirror.Pos(line, t.end + 1));

    if (t.start === next_token.start) {
      break;
    }
    if (next_token.type != null) {
      last_interesting_token = next_token;
    }
    t = next_token;
  }
  return last_interesting_token;
}

function propertyPath(cm, token, line) {
  let s;
  let t = token;
  const path = [];

  while (true) {
    // TODO i don't understand why this isn't `t.start - 1`, but that doesn't work for the first character
    const previous_token = cm.getTokenAt(CodeMirror.Pos(line, t.start));

    if (t.start === previous_token.start || previous_token.type !== 'variable') {
      break;
    }
    t = previous_token;
    if (t.string[0] === '.') {
      s = t.string.slice(1);
    } else {
      s = t.string;
    }
    path.unshift(s);
  }
  return path;
}

function followPath(o, path) {
  let result = o;

  for (let i = 0; i < path.length; i++) {
    const s = path[i];

    if (result == null) {
      return;
    }
    result = result[s];
  }

  return result != null && result.module_name ? null : result;
}

function collectStringSuggestions(ctx, string) {
  return Q.all(_.flatten(_.map(Context.collect_extension_points(ctx, 'suggest_strings'), (fn) => {
    return fn(ctx, string);
  }))).then(function (suggestions) {
    return _.flatten(suggestions);
  });
}

function collectKeySuggestions(ctx, string) {
  return _.flatten(_.map(Context.collect_extension_points(ctx, 'suggest_keys'), (fn) => {
    return fn(ctx, string);
  }));
}

export function suggest(cm, showHints) {
  let end_offset, full_s, path, prefix, string;
  const cur = cm.getCursor();
  const token = cm.getTokenAt(cur);

  if (token.type === 'string') {
    const open = token.string[0];

    string = token.string.slice(1);
    const close = string[string.length - 1];

    if (open === close) {
      string = string.slice(0, -1);
      end_offset = 1;
    } else {
      end_offset = 0;
    }
    const promise = collectStringSuggestions(cm.ctx, string);

    return promise.done((list) => {
      return showHints({
        list,
        from: CodeMirror.Pos(cur.line, token.start + 1),
        to: CodeMirror.Pos(cur.line, token.end - end_offset)
      });
    });
  } else {
    if (token.type === 'variable' && token.string[0] === '.' || token.type === 'error' && token.string === '.') {
      path = propertyPath(cm, token, cur.line);
      prefix = '.';
      full_s = token.string.slice(1);
    } else {
      path = [];
      prefix = '';
      full_s = token.string;
    }
    const sub_s = full_s.slice(0, cur.ch - token.start);
    const next_token = tokenAfter(cm, token, cur.line);
    const imported = followPath(cm.ctx.imported, path);

    const collectSuggestions = (s) => {
      const list = [];

      for (const k in imported) {
        if (k.indexOf(s) === 0) {
          list.push(prefix + k);
        }
      }

      if (path.length === 0) {
        let key_suggestions = collectKeySuggestions(cm.ctx, s);

        if ((next_token != null ? next_token.string : void 0) !== ':') {
          key_suggestions = _.map(key_suggestions, function (k) {
            return k + ':';
          });
        }

        list.push.apply(list, key_suggestions);
      }
      return list;
    }

    let list = collectSuggestions(full_s);

    if (list.length > 0) {
      return showHints({
        list,
        from: CodeMirror.Pos(cur.line, token.start),
        to: CodeMirror.Pos(cur.line, token.end)
      });
    } else {
      list = collectSuggestions(sub_s);
      return showHints({
        list,
        from: CodeMirror.Pos(cur.line, token.start),
        to: CodeMirror.Pos(cur.line, cur.ch)
      });
    }
  }
}
