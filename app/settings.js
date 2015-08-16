import _ from 'underscore';
import $ from 'jquery';
import Bacon from 'baconjs';
import * as Modules from './modules';
import * as Context from './context';

function splitKeysAndValue(keysAndValue) {
  keysAndValue = [...keysAndValue];
  const value = keysAndValue.pop();
  const keys = keysAndValue;
  return {keys, value};
}

Modules.export(exports, 'settings', ({fn}) => {
  fn('set', 'Sets a user setting', (ctx, keysAndValue) => {
    const {keys, value} = splitKeysAndValue(keysAndValue);
    user_settings.set(...keys, value);
  });

  fn('get', 'Gets a setting', (ctx, ...keys) => {
    return Context.value(global_settings.get(...keys));
  });
});

function keysOverlap(a, b) {
  const [longer, shorter] = a.length < b.length ? [b, a] : [a, b];
  return _.isEqual(longer.slice(0, shorter.length), shorter);
}

export function create(overrides={get: () => {}}) {
  const changeBus = new Bacon.Bus();

  if (overrides.changes != null) {
    changeBus.plug(overrides.changes);
  }

  let data = {};
  function get(d, keys) {
    if (keys.length === 0) {
      return d;
    }
    if (d == null) {
      return d;
    }
    let key;
    [key, ...keys] = keys;
    return get(d[key], keys);
  }

  function set(d, value, keys) {
    if (keys.length === 0) {
      data = _.clone(value);
    }

    let key;
    [key, ...keys] = keys;
    if (keys.length === 0) {
      return d[key] = value;
    } else {
      return set(d[key] != null ? d[key] : d[key] = {}, value, keys);
    }
  }

  function with_prefix(...prefix) {
    return {
      get(...keys) {
        const k = prefix.concat(keys);
        const override = overrides.get(...k);
        const value = get(data, k);

        if (override == null) {
          return value;
        } else if (_.isObject(override) && _.isObject(value)) {
          return $.extend(true, {}, value, override);
        } else {
          return override;
        }
      },

      get_without_overrides(...keys) {
        return get(data, prefix.concat(keys));
      },

      set(keysAndValue) {
        const {keys, value} = splitKeysAndValue(keysAndValue);
        const k = prefix.concat(keys);

        set(data, value, k);
        changeBus.push(k);
        return this;
      },

      default(keysAndValue) {
        const {keys, value} = splitKeysAndValue(keysAndValue);
        return this.get(...keys) || this.set(...keys, value);
      },

      toProperty(...keys) {
        const current = this.get(...keys);
        const k = prefix.concat(keys);

        return changeBus.filter((changedKey) => keysOverlap(k, changedKey))
          .map(() => _.clone(this.get(...keys)))
          .skipDuplicates(_.isEqual).toProperty(current);
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
const global_settings = create(user_settings);

Object.assign(exports, global_settings);
