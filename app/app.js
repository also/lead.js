/* globals __webpack_public_path__: true */

require('object.assign').shim();

import * as React from 'react';
import URI from 'URIjs';
import Router from 'react-router';
import Settings from './settings';
import * as Modules from './modules';
import * as Modal from './modal';
import AppRoutes from './routes';
import * as Defaults from './defaultApp';
import {encodeNotebookValue} from './notebook';

Settings.default('app', 'intro_command', `help 'introduction'`);

const InitializationFailureModal = React.createClass({
  render() {
    const footer = <button onClick={this.props.dismiss}>OK</button>;

    return (
      <Modal.ModalComponent title='Lead Failed to Start Properly' footer={footer}>
        <p>An error occurred while starting lead. More details may be available in the browser's console. Some features might not be available. Try reloading this page.</p>
        <p style={{marginTop: '1em'}}>Message: {this.props.error.message || this.props.error}</p>
      </Modal.ModalComponent>
    );
  }
});

function bindUserSettingsToLocalStorage(key) {
  try {
    Settings.user_settings.set(JSON.parse(localStorage.getItem(key)) || {});
  } catch (err) {
    console.error('failed loading user settings', err);
  }

  window.addEventListener('storage', (e) => {
    if (e.key === key) {
      console.log('updating user settings');
      try {
        return Settings.user_settings.set(JSON.parse(e.newValue) || {});
      } catch (err) {
        return console.error('failed updating user settings', err);
      }
    }
  });

  Settings.user_settings.changes.onValue(function () {
    return localStorage.setItem(key, JSON.stringify(Settings.user_settings.get()));
  });
}

export function init_app(target, options={}) {
  bindUserSettingsToLocalStorage('lead_user_settings');
  const publicUrl = Settings.get('app', 'publicUrl');

  if (publicUrl != null) {
    __webpack_public_path__ = publicUrl;
  }

  const modules = {...Defaults.modules, ...options.modules};
  const imports = [...Defaults.imports, ...(Settings.get('app', 'imports') || [])];
  const app = {imports, modules};
  const extraRoutes = options.extraRoutes || [];
  const bodyWrapper = options.bodyWrapper;

  if (location.search !== '') {
    let query;
    const uri = URI(location.href);

    if (uri.hash() === '') {
      query = encodeURIComponent(uri.query());
    } else {
      query = uri.query();
    }
    uri.hash(uri.hash() + '?' + query);
    uri.query(null);
    window.history.replaceState(null, document.title, uri.toString());
  }

  const initializationPromise = Modules.init_modules(modules);
  initializationPromise.fail(error => {
    console.error('Failure initializing modules', error);
    return Modal.pushModal({
      handler: InitializationFailureModal,
      props: {error}
    });
  });

  return React.renderComponent(<AppRoutes {...{bodyWrapper, app, initializationPromise, extraRoutes}}/>, target);
}

export function raw_cell_url(ctx, value) {
  const encoded = encodeNotebookValue(value);

  return URI(ctx.app.appComponent.makeHref('raw_notebook', {splat: encoded}))
    .absoluteTo(location.href)
    .toString();
}

window.lead = {
  settings: Settings,
  init_app: init_app,
  Router: Router,
  React: React
};

window.React = React;
