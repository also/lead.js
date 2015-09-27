import * as Immutable from 'immutable';

import * as actionTypes from './actionTypes';


const initialState = Immutable.fromJS({settings: {}});

export default function reduce(state=initialState, action) {
  switch (action.type) {
  case actionTypes.SETTINGS_CHANGED:
    return state.setIn(['settings'], action.settings);

  case actionTypes.CORE_INIT:
    return state.setIn(['coreInit'], Immutable.fromJS({state: action.state, value: action.value}));

  default:
    return state;
  }
}
