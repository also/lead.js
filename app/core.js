import underscore from 'underscore';

const exports = {};

Object.assign(exports, underscore, {
  logError(...message) {
    const error = message.pop();

    let e;

    if (error && error.stack && error.stack.indexOf(error.message) === 0) {
      e = error.stack;
    } else {
      e = error;
    }

    return console.error.apply(console, message.concat([e]));
  },

  errorInfo(error) {
    let message, stack, trace;

    if ((error == null) || underscore.isString(error)) {
      message = 'Error: ' + error;
    } else {
      try {
        message = '' + error;
      } catch (e) {
        message = 'Unknown Error';
      }
    }

    if (error instanceof Error && error.stack) {
      if (error.stack.indexOf(message + '\n') === 0) {
        stack = error.stack.slice(message.length + 1);
      } else {
        stack = error.stack;
      }
      trace = stack.split('\n');
    } else {
      trace = null;
    }

    return {error, message, trace};
  },

  intersperse(array, v) {
    const result = array.slice(0, 1);
    underscore.each(array.slice(1), (e) => result.push(v, e));
    return result;
  },

  startsWith(str, starts) {
    if (starts === '') {
      return true;
    }

    if (str === null || starts === null) {
      return false;
    }

    str = String(str);
    starts = String(starts);

    return str.length >= starts.length && str.slice(0, starts.length) === starts;
  }
});

export default exports;
