/* globals mocha: false */

import Mocha from 'mocha';
import Q from 'q';
import _ from 'underscore';


const m = typeof mocha !== 'undefined' ? mocha : new Mocha();

if (typeof m.setup === 'function') {
  m.setup('bdd');
}

m.suite.emit('pre-require', global, 'hack', m);

const tests = ['dsl', 'settings', 'context', 'server', 'github', 'html', 'graph/utils'];

if (typeof window !== 'undefined') {
  tests.push('notebook');
}

function collectSuites(suites) {
  return suites.map(({title, tests, suites}) => {
    return {
      title,
      tests: collectTests(tests),
      suites: collectSuites(suites)
    };
  });
}

function collectTests(tests) {
  return tests.map((test) => {
    return _.pick(test, 'async', 'duration', 'pending', 'speed', 'state', 'sync', 'timedOut', 'title', 'type');
  });
}

const runTests = function () {
  const deferred = Q.defer();
  const runner = m.run((failed) => {
    const result = Object.assign({}, runner.stats, {
      results: collectSuites(runner.suite.suites)
    });

    if (failed > 0) {
      return deferred.reject(result);
    } else {
      return deferred.resolve(result);
    }
  });

  return deferred.promise;
};

export function run() {
  _.each(tests, (t) => require(`../${t}.test`));

  return runTests();
}
