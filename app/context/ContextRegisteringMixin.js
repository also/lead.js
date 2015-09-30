import {register, unregister} from './contextRegistry';


export default {
  componentWillMount() {
    register(this, this.props.ctx);
  },

  componentWillUnmount() {
    unregister(this);
  }
};
