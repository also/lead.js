import * as types from './actionTypes';

export function settingsChanged(settings) {
  return {type: types.SETTINGS_CHANGED, settings};
}

export function coreInit(state, value) {
  return {type: types.CORE_INIT, state, value};
}

export function pushModal(modal) {
  return {type: types.PUSH_MODAL, modal};
}

export function removeModal(modal) {
  return {type: types.REMOVE_MODAL, modal};
}
