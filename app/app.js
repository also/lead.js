/* globals __webpack_public_path__: true */
/* exported __webpack_public_path__ */

require('object.assign').shim();

import * as React from 'react';
import {Provider} from 'react-redux';
import URI from 'urijs';
import Router from 'react-router';
import {createStore} from 'redux';

import reducer from './reducer';
import notebookReducer from './notebook/reducer';
import {combineReducers} from './store';
import * as Settings from './settings';
import * as Modules from './modules';
import * as Modal from './modal';
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

  const modules = {...Defaults.modules, ...options.modules};
  const imports = [...Defaults.imports, ...(Settings.get('app', 'imports') || [])];
  const extraRoutes = options.extraRoutes || [];
  const bodyWrapper = options.bodyWrapper;

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

  const store = createStore(combineReducers([reducer, notebookReducer]));

  store.dispatch(actions.coreInit('pending'));

  const ctx = {
    settings: {user: Settings.user_settings, global: Settings.global_settings},
    imports,
    modules,
    store,
    ctxType: 'app'
  };

  ctx.app = ctx;

  const initializationPromise = Modules.init_modules(ctx, modules);
  initializationPromise.then(() => {
    store.dispatch(actions.coreInit('finished'));
  });
  initializationPromise.fail((error) => {
    store.dispatch(actions.coreInit('finished'));
    console.error('Failure initializing modules', error);
    return store.dispatch(actions.pushModal({
      handler: InitializationFailureModal,
      props: {error}
    }));
  });

  store.dispatch(actions.settingsChanged(Settings.getRaw()));
  Settings.changes.onValue(() => {
    store.dispatch(actions.settingsChanged(Settings.getRaw()));
  });

  React.render(
    <Provider store={store}>
      {() => <AppRoutes {...{bodyWrapper, ctx, extraRoutes}}/>}
    </Provider>
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
