import React from 'react';
import _ from 'underscore';

import {ObservableMixin} from '../components';

export default _.extend({}, ObservableMixin, {
  contextTypes: {
    cursorPosition: React.PropTypes.object.isRequired
  },

  getObservable(props, context) {
    return context.cursorPosition;
  }
});
