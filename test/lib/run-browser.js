import '!style!css!mocha/mocha.css';
import {run} from './runner';

document.write('<div id=mocha></div>');

window.run = (callback) => {
  run().then(callback, callback);
};

// automated tests will load the page with ?pause and call run
if (window.location.search !== '?pause') {
  window.run();
}
