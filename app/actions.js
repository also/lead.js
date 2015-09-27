import * as types from './actionTypes';

export function settingsChanged(settings) {
  return {type: types.SETTINGS_CHANGED, settings};
}
