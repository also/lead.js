## Building

### Web

lead.js uses [webpack](http://webpack.github.io/docs/) to build JavaScript that runs in the browser. The grunt task `webpack:web` task builds using the `webpack.config.js` file. The `webpack` and `webpack-dev-server` commands can both be used without grunt.

The `web` grunt task creates a complete working lead.js build in `build/web`.

### node.js

lead.js runs directly in node.js. To build, the CoffeeScript files in `app` are compiled into `build/node/app` by the `node` grunt task.

## Tests

The simplest tests are run in node.js itself.

```
grunt test-node
```

These tests are limited, and can't test many features that require a browser or DOM.

To test against a browser, the `connect` server task needs to be running. The test suite will be available at http://localhost:8000/test/runner.html.

For quick, headless tests, the suite can be loaded in phantomjs

```
grunt connect test-phantomjs
```

### Local Selenium Tests

Running Selenium tests locally requires the Selenium Server, Chrome webdriver, Chrome, and Firefox to be installed.

Run the Selenium Server

```
java -Dwebdriver.chrome.driver=chromedriver -jar selenium-server-standalone-2.42.2.jar
```

Run the tests locally:

```
grunt connect test-selenium-app-local
grunt test-selenium-unit-local
```

### Remote Selenium Tests

Running Selenium tests remotely uses Sauce Labs, and requires an account.

The Sauce Labs credentials are stored in the environment variables `SAUCE_USERNAME` and `SAUCE_ACCESS_KEY`. Set these before running any remote tests:

```
export SAUCE_USERNAME=...
export SAUCE_ACCESS_KEY=...
```

Run the remote Selenium Tests:

```
grunt test-selenium-all-remote
```
