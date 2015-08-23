import Q from 'q';
import _ from 'underscore';
import request from 'request';
import SauceTunnel from 'sauce-tunnel';
import wd from 'wd';
import expect from 'expect.js';


const username = process.env.SAUCE_USERNAME;
const accessKey = process.env.SAUCE_accessKey;
const base_url = 'https://' + username + ':' + accessKey + '@saucelabs.com/rest/v1/' + username;

export function start_tunnel() {
  const tunnel = new SauceTunnel(username, accessKey, null, true);
  const started = Q.defer();

  tunnel.start((status) => {
    if (status === true) {
      return started.resolve(tunnel);
    } else {
      return started.reject(status);
    }
  });
  return started.promise;
}

export function run_with_tunnel(fn) {
  return start_tunnel().then((tunnel) => {
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

export function update_sauce_job(jobId, details) {
  return Q.nfcall(request, {
    url: base_url + '/jobs/' + jobId,
    method: 'put',
    body: details,
    json: true
  });
}

function runInBrowser({driverOpts, initOpts}, browser_opts, fn) {
  const browser = wd.promiseChainRemote(driverOpts);

  return browser.init(_.extend({}, initOpts != null ? initOpts : {}, browser_opts)).then(() => {
    return browser.sessionCapabilities().then((c) => {
      return browser.capabilities = c;
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
  })['finally'](() => {
    return browser.quit().fail(() => {});
  });
}

export function run_in_sauce_browsers(driver, sauceOpts, browsers, fn) {
  return run_in_browsers(driver, _.map(browsers, (b) => {
    return _.extend({}, sauceOpts, b);
  }), (browser) => {
    const result = fn(browser);

    return result['finally'](() => {
      return update_sauce_job(browser.sessionID, {
        passed: result.isFulfilled()
      });
    });
  });
}

export function run_in_browsers(driver, browsers, fn) {
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

export function run_remotely(sauceOpts, browsers, fn) {
  return run_with_tunnel((driver) => {
    return run_in_sauce_browsers(driver, sauceOpts, browsers, fn);
  });
}

export function run_locally(browsers, fn) {
  return run_in_browsers({}, browsers, fn);
}

export function print_summary(results) {
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

export function unit_tests(browser) {
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
