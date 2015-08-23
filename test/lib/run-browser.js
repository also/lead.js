import '!style!css!mocha/mocha.css';
import runner from '../runner';

document.write('<div id=mocha></div>');

window.run = (callback) => {
  runner.run().then(callback, callback);
}

// automated tests will load the page with ?pause and call run
if (window.location.search !== '?pause') {
  window.run();
}
