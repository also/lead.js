import Q from 'q';
import _ from 'underscore';
import request from 'request';
import SauceTunnel from 'sauce-tunnel';
import wd from 'wd';
import expect from 'expect.js';


const username = process.env.SAUCE_USERNAME;
const accessKey = process.env.SAUCE_ACCESS_KEY;

const baseUrl = 'https://' + username + ':' + accessKey + '@saucelabs.com/rest/v1/' + username;

function startTunnel() {
  if (!(username && accessKey)) {
    return Q.reject(new Error('Missing username/access key'));
  }

  const tunnel = new SauceTunnel(username, accessKey, null, true);
  const started = Q.defer();

  tunnel.start((status) => {
    if (status === true) {
      return started.resolve(tunnel);
    } else {
      return started.reject(new Error('Failed to start tunnel'));
    }
  });
  return started.promise;
}

export function runWithTunnel(fn) {
  return startTunnel().then((tunnel) => {
    const driverOpts = {
      host: 'ondemand.saucelabs.com',
      port: '80',
      username: username,
      accessKey: accessKey
    };
    const initOpts = {
      'tunnel-identifier': tunnel.identifier
    };

    return Q(fn({
      driverOpts: driverOpts,
      initOpts: initOpts
    }))['finally'](() => {
      return tunnel.stop(() => {});
    });
  });
}

function updateSauceJob(jobId, details) {
  return Q.nfcall(request, {
    url: baseUrl + '/jobs/' + jobId,
    method: 'put',
    body: details,
    json: true
  });
}

function runInBrowser({driverOpts, initOpts}, browserOpts, fn) {
  const browser = wd.promiseChainRemote(driverOpts);

  return browser.init(Object.assign({}, initOpts, browserOpts)).then(() => {
    return browser.sessionCapabilities().then((c) => {
      browser.capabilities = c;
    });
  }).then(() => fn(browser))
  .then((result) => {
    return {
      browser: browser,
      result: result
    };
  }, (result) => {
    return Q.reject({
      browser: browser,
      result: result
    });
  }).finally(() => {
    return browser.quit().fail(() => {});
  });
}

export function runInSauceBrowsers(driver, sauceOpts, browsers, fn) {
  return runInBrowsers(driver, _.map(browsers, (b) => {
    return Object.assign({}, sauceOpts, b);
  }), (browser) => {
    const result = fn(browser);

    return result.finally(() => {
      return updateSauceJob(browser.sessionID, {
        passed: result.isFulfilled()
      });
    });
  });
}

function runInBrowsers(driver, browsers, fn) {
  const promises = _.map(browsers, (browser) => {
    return runInBrowser(driver, browser, fn);
  });

  return Q.allSettled(promises).then(() => {
    if (_.every(promises, (p) => {
      return p.isFulfilled();
    })) {
      return Q.resolve(promises);
    } else {
      return Q.reject(promises);
    }
  });
}

export function runRemotely(sauceOpts, browsers, fn) {
  return runWithTunnel((driver) => {
    return runInSauceBrowsers(driver, sauceOpts, browsers, fn);
  });
}

export function runLocally(browsers, fn) {
  return runInBrowsers({}, browsers, fn);
}

export function printSummary(results) {
  if (results instanceof Error) {
    console.log(results.stack);
    return;
  }

  return _.map(results, (r) => {
    const snapshot = r.inspect();
    const state = snapshot.state;

    let value;
    if (state === 'fulfilled') {
      value = snapshot.value;
    } else {
      value = snapshot.reason;
    }

    const {browser, result} = value;
    let {capabilities, defaultCapabilities} = browser;
    if (capabilities == null) {
      console.log('(failed creating browser)');
      capabilities = defaultCapabilities;
    }
    console.log(capabilities.browserName + ' ' + capabilities.version + ' (' + capabilities.platform + ')');
    if (state === 'fulfilled') {
      console.log('passed');
    } else {
      console.log('failed');
      const jsonwireError = result['jsonwire-error'];

      if (jsonwireError != null) {
        console.log(jsonwireError.status + ' ' + jsonwireError.summary + ': ' + jsonwireError.detail);
      } else {
        console.log('unknown error:');
        if (result.stack) {
          console.log(result.stack);
        } else {
          console.log(result.toString());
        }
        console.log(JSON.stringify(result));
      }
    }
    return console.log();
  });
}

export function unitTests(browser) {
  return browser.setAsyncScriptTimeout(10000).get('http://localhost:8000/test/runner.html?pause').title().then((title) => {
    expect(title).to.be('lead.js test runner');
    return browser.executeAsync('run(arguments[0])').then((results) => {
      if (results.failures > 0) {
        return Q.reject(results);
      } else {
        return results;
      }
    });
  });
}
