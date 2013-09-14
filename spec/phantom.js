console.log('loading tests');

var page = require('webpage').create();
page.onConsoleMessage = function(msg) {
    console.log(msg);
};
var url = 'http://localhost:9292/runner.html';
page.open(url);

function configureJasmine(env, phantom) {
  var callback = function(runner) {
      var results = runner.results();
      window.callPhantom(results);
  };
  env.addReporter(new jasmine.ConsoleReporter(function(msg) {console.log(msg);}, callback, true));
}

page.onInitialized = function() {
  page.evaluate(function(configureJasmine, phantom) {
    window.configure_jasmine = function(env) { configureJasmine(env, phantom) };
  }, configureJasmine, phantom);
};

page.onCallback = function(results) {
  if (results.failedCount > 0) {
    phantom.exit(1);
  }
  else {
    phantom.exit(0);
  }
};

function timeout() {
  console.log('tests failed to complete');
  phantom.exit(2);
}

setTimeout(timeout, 10000);
