import React from 'react';

import {ObservableMixin} from '../components';


export default Object.assign({}, ObservableMixin, {
  contextTypes: {
    cursorPosition: React.PropTypes.object.isRequired
  },

  getObservable(props, context) {
    return context.cursorPosition;
  }
});
