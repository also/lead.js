import * as types from './actionTypes';

export function settingsChanged(settings) {
  return {type: types.SETTINGS_CHANGED, settings};
}

export function coreInit(state, value) {
  return {type: types.CORE_INIT, state, value};
}
