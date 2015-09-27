import _ from 'underscore';
import Bacon from 'baconjs';
import * as Immutable from 'immutable';

import {splitKeysAndValue} from './utils';


function keysOverlap(a, b) {
  const [longer, shorter] = a.length < b.length ? [b, a] : [a, b];
  return _.isEqual(longer.slice(0, shorter.length), shorter);
}

const toJS = (v) => v instanceof Immutable.Iterable ? v.toJS() : v;

export function create(overrides={getRaw: () => null}) {
  const changeBus = new Bacon.Bus();

  if (overrides.changes != null) {
    changeBus.plug(overrides.changes);
  }

  let data = new Immutable.Map();

  function with_prefix(...prefix) {
    return {
      getRaw(...keys) {
        const k = prefix.concat(keys);
        const override = overrides.getRaw(...k);
        const value = data.getIn(k);

        if (override == null) {
          return value;
        } else if (override instanceof Immutable.Map && value instanceof Immutable.Map) {
          return value.mergeDeep(override);
        } else {
          return override;
        }
      },

      get(...keys) {
        return toJS(this.getRaw(...keys));
      },

      get_without_overrides(...keys) {
        return data.getIn(prefix.concat(keys));
      },

      set(...keysAndValue) {
        const {keys, value} = splitKeysAndValue(keysAndValue);
        const k = prefix.concat(keys);

        data = data.setIn(k, Immutable.fromJS(value));
        changeBus.push(k);
        return this;
      },

      default(...keysAndValue) {
        const {keys, value} = splitKeysAndValue(keysAndValue);
        return this.get(...keys) || this.set(...keys, value);
      },

      toProperty(...keys) {
        const current = this.get(...keys);
        const k = prefix.concat(keys);

        return changeBus.filter((changedKey) => keysOverlap(k, changedKey))
          .map(() => this.getRaw(...keys))
          .skipDuplicates(Immutable.is)
          .map(toJS)
          .toProperty(current);
      },

      toModel(...keys) {
        const current = this.get(...keys);
        const model = new Bacon.Model(current);

        model.addSource(this.toProperty(...keys));
        return model;
      }
    };
  }

  const settings = with_prefix();

  settings.changes = changeBus.map(_.identity);
  settings.with_prefix = with_prefix;
  return settings;
}

export const user_settings = create();
export const global_settings = create(user_settings);

Object.assign(exports, global_settings);
