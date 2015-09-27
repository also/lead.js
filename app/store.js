import * as Immutable from 'immutable';


const COLLECT_INITIAL_STATE = Symbol();

function collectInitialState(reducers, action) {
  return reducers.reduce((state, reducer) => state.merge(reducer(undefined, action)), new Immutable.Map());
}

function applyReducers(reducers, state, action) {
  return reducers.reduce((newState, reducer) => state.merge(reducer(newState, action)), state);
}

export function combineReducers(reducers) {
  return function reducer(state=COLLECT_INITIAL_STATE, action) {
    console.log('action', action.type);
    return state === COLLECT_INITIAL_STATE
      ? collectInitialState(reducers, action)
      : applyReducers(reducers, state, action);
  };
}
