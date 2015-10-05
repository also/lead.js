import * as React from 'react';
import shallowEqual from 'react/lib/shallowEqual';

// using this is probably a bad sign
export function replaceOnPropChange(Component) {
  return React.createClass({
    getInitialState() {
      return {key: 1};
    },

    componentWillReceiveProps(nextProps) {
      if (!shallowEqual(this.props, nextProps)) {
        this.setState({key: this.state.key + 1});
      }
    },

    render() {
      const {key} = this.state;

      return <Component key={key} {...this.props}/>;
    }
  });
}
