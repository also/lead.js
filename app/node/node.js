import {jsdom} from 'jsdom';

function enableGlobalWindow() {
  if (!global.window) {
    const doc = jsdom('<html><body></body></html>');

    global.window = doc.parentWindow;
    global.document = doc;
    return global.navigator = {
      userAgent: 'lol'
    };
  }
}

function _require(m) {
  return require('./' + m);
}

export {_require as require};

enableGlobalWindow();
