import * as React from 'react';

import * as Server from '../server';
import * as Http from '../http';
import * as Settings from '../settings';
import {ModalComponent} from '../app';
import {ContextAwareMixin} from '../contextComponents';


export default React.createClass({
  mixins: [ContextAwareMixin],

  getInitialState() {
    const {query} = this.props;
    const ctx = this.ctx();
    const promise = Http.post(ctx, Server.url(ctx, 'github/oauth/token'), query);
    // TODO this is some bad promising
    promise.finally(() => this.setState({finished: true})).done();

    promise.then(({access_token}) => {
      if (access_token != null) {
        Settings.user_settings.set('github', 'githubs', Settings.get('github', 'default'), 'access_token', access_token);
      }
    })
    .done();

    return {promise};
  },

  renderLoaded(promiseState) {
    if (promiseState.value.access_token != null) {
      return 'You have successfully authorized lead to use GitHub';
    } else if (promiseState.value.error_description) {
      return promiseState.value.error_description;
    } else {
      return 'Unknown error';
    }
  },

  render() {
    const promiseState = this.state.promise.inspect();

    let body;
    let footer = null;
    if (promiseState.state === 'pending') {
      body = 'Authenticating with GitHub...';
    } else if (promiseState.state === 'fulfilled') {
      body = this.renderLoaded(promiseState);
      footer = <div><button onClick={() => window.close()}>OK</button></div>;
    } else {
      body = 'Unknown error';
    }

    return (
      <div className='modal-bg'>
        <div className='modal-fg'>
          <ModalComponent footer={footer} title='GitHub Authentication'>
            <div>{body}</div>
          </ModalComponent>
        </div>
      </div>
    );
  }
});
