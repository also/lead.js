import {jsdom} from 'jsdom';

function enableGlobalWindow() {
  if (!global.window) {
    const doc = jsdom("<html><body></body></html>");

    global.window = doc.parentWindow;
    global.document = doc;
    return global.navigator = {
      userAgent: 'lol'
    };
  }
}

export function require(m) {
  return require("./" + m);
}

enableGlobalWindow();
