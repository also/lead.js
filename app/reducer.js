import * as Immutable from 'immutable';

import * as actionTypes from './actionTypes';


const initialState = Immutable.fromJS({settings: {}, modals: []});

export default function reduce(state=initialState, action) {
  switch (action.type) {
  case actionTypes.SETTINGS_CHANGED:
    return state.setIn(['settings'], action.settings);

  case actionTypes.CORE_INIT:
    return state.setIn(['coreInit'], Immutable.fromJS({state: action.state, value: action.value}));

  case actionTypes.PUSH_MODAL:
    return state.updateIn(['modals'], (modals) => modals.push(action.modal));

  case actionTypes.REMOVE_MODAL:
    return state.updateIn(['modals'], (modals) => modals.filterNot((modal) => modal === action.modal));

  default:
    return state;
  }
}
