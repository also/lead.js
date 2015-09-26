import _ from 'underscore';
import React from 'react/addons';

import {ObservableMixin} from '../components';
import {isRunContext} from '.';


export default React.createClass({
  displayName: 'ContextLayoutComponent',

  mixins: [ObservableMixin],

  propTypes: {
    ctx(c) {
      if (!isRunContext(c.ctx)) {
        throw new Error('context required');
      }
    }
  },

  getObservable(props) {
    return props.ctx.componentList.model;
  },

  render() {
    const {ctx} = this.props;

    const children = _.map(this.state.value, ({key, component}) => {
      let c;

      if (_.isFunction(component)) {
        c = component();
      } else {
        c = component;
      }

      return React.addons.cloneWithProps(c, {key});
    });

    return React.createElement(ctx.layout, Object.assign({children}, ctx.layout_props));
  }
});
