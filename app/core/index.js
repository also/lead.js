import {createStore} from 'redux';

import * as Settings from '../settings';
import reducer from '../reducer';
import notebookReducer from '../notebook/reducer';
import {combineReducers} from '../store';
import * as Modules from '../modules';
import * as actions from '../actions';

export function createLeadContext({imports=[], modules={}}={}) {
  const store = createStore(combineReducers([reducer, notebookReducer]));
  store.dispatch(actions.coreInit('pending'));

  const ctx = {
    settings: {user: Settings.user_settings, global: Settings.global_settings},
    imports,
    modules,
    store
  };

  ctx.app = ctx;

  const initializationPromise = Modules.init_modules(ctx, modules)
  .then(() => {
    store.dispatch(actions.coreInit('finished'));
  });

  initializationPromise.fail((error) => {
    console.error('Failure initializing modules', error);
    store.dispatch(actions.coreInit('failed', error));
  });

  ctx.initializationPromise = initializationPromise;

  store.dispatch(actions.settingsChanged(Settings.getRaw()));
  Settings.changes.onValue(() => {
    store.dispatch(actions.settingsChanged(Settings.getRaw()));
  });

  return ctx;
}
