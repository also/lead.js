import * as Modules from '../modules';
import * as Context from '../context';

import {splitKeysAndValue} from './utils';

Modules.export(exports, 'settings', ({fn}) => {
  fn('set', 'Sets a user setting', (ctx, ...keysAndValue) => {
    const {keys, value} = splitKeysAndValue(keysAndValue);
    ctx.settings.user.set(...keys, value);
  });

  fn('get', 'Gets a setting', (ctx, ...keys) => {
    return Context.value(ctx.settings.global.get(...keys));
  });
});
