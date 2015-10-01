/* globals __webpack_public_path__: true */
/* exported __webpack_public_path__ */

import * as React from 'react';
import URI from 'urijs';
import Router from 'react-router';

import {createLeadContext} from './core';
import * as Settings from './settings';
import * as Modal from './modal';
import RootComponent from './core/RootComponent';
import AppRoutes from './routes';
import * as Defaults from './defaultApp';
import {encodeNotebookValue} from './notebook';
import * as actions from './actions';


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

export function initApp(target, options={}) {
  bindUserSettingsToLocalStorage('lead_user_settings');
  const publicUrl = Settings.get('app', 'publicUrl');

  if (publicUrl != null) {
    __webpack_public_path__ = publicUrl;
  }

  if (location.search !== '') {
    let query;
    const uri = new URI(location.href);

    if (uri.hash() === '') {
      query = encodeURIComponent(uri.query());
    } else {
      query = uri.query();
    }
    uri.hash(uri.hash() + '?' + query);
    uri.query(null);
    window.history.replaceState(null, document.title, uri.toString());
  }

  const modules = {...Defaults.modules, ...options.modules};
  const imports = [...Defaults.imports, ...(Settings.get('app', 'imports') || [])];
  const extraRoutes = options.extraRoutes || [];
  const bodyWrapper = options.bodyWrapper;

  const ctx = createLeadContext({...options, imports, modules});

  ctx.initializationPromise.fail((error) => {
    return ctx.store.dispatch(actions.pushModal({
      handler: InitializationFailureModal,
      props: {error}
    }));
  });

  React.render(
    <RootComponent ctx={ctx}>
      {() => <AppRoutes {...{bodyWrapper, extraRoutes}}/>}
    </RootComponent>
  , target);
}

export function raw_cell_url(ctx, value) {
  const encoded = encodeNotebookValue(value);

  return new URI(ctx.app.appComponent.makeHref('raw_notebook', {splat: encoded}))
    .absoluteTo(location.href)
    .toString();
}

window.lead = {
  settings: Settings,
  initApp: initApp,
  Router: Router,
  React: React
};
