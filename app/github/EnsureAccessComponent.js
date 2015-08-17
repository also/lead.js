import * as React from 'react';
import * as Bacon from 'bacon.model';
import _ from 'underscore';

import * as Server from '../server';
import * as Http from '../http';
import * as Github from '../github';

import AccessTokenForm from './AccessTokenForm';
import {ModalComponent} from '../modal';
import {ToggleComponent} from '../components';


export default React.createClass({
  getInitialState() {
    const {ctx, site} = this.props;
    const tokens = new Bacon.Bus();
    const unsubscribe = tokens.plug(ctx.settings.global.toProperty('githubs', site.domain, 'access_token').filter(_.identity));
    const userDetails = tokens.flatMapLatest((accessToken) => {
      this.setState({tokenStatus: 'validating'});

      return Bacon.combineTemplate({
        user: Bacon.fromPromise(Http.get(ctx, Github.toApiUrl(ctx, site, '/user').setQuery({
          access_token: accessToken
        }))),
        accessToken: accessToken
      }).changes();
    });

    userDetails.onValue(({user, accessToken}) => {
      if (ctx.settings.user.get('github', 'githubs', site.domain, 'access_token') !== accessToken) {
        ctx.settings.user.set('github', 'githubs', site.domain, 'access_token', accessToken);
      }
      this.props.deferred.resolve();
      return this.setState({user, tokenStatus: 'valid'});
    });

    userDetails.onError(() => {
      return this.setState({
        tokenStatus: 'invalid'
      });
    });

    return {
      tokenStatus: 'needed',
      user: null,
      tokens,
      site,
      unsubscribe
    };
  },

  cancel() {
    return this.props.deferred.reject('GitHub Authentication Cancelled');
  },

  componentWillUnmount() {
    let base;
    return typeof (base = this.state).unsubscribe === 'function' ? base.unsubscribe() : void 0;
  },

  render() {
    const {ctx} = this.props;

    const message = () => {
      switch (this.state.tokenStatus) {
      case 'needed':
        return <strong/>;
      case 'validating':
        return <strong>Validating your token</strong>;
      case 'valid':
        return <strong>Logged in as {this.state.user.name}</strong>;
      case 'invalid':
        return <strong>That access token didn't work. Try again?</strong>;
      }
    }();

    let url = null;

    if (Server.hasFeature(ctx, 'github-oauth')) {
      try {
        url = Server.url(ctx, 'github/oauth/authorize');
      } catch (e) {
        // ignore
      }
    }

    const tokenForm = (
      <div>
        <AccessTokenForm handle_token={(t) => this.state.tokens.push(t)}/>
        <p>{message}</p>
      </div>
    );

    const body = url
      ? (
        <div>
          <div style={{marginBottom: '1em'}}>
            <a href={url} target='_blank'>Log in to GitHub</a>
          </div>
          <ToggleComponent title='Advanced'>
            {tokenForm}
          </ToggleComponent>
        </div>
      )
      : tokenForm;

    const footer = <button onClick={this.cancel}>Cancel</button>;

    return (
      <ModalComponent footer={footer} title='GitHub Authentication'>
        {body}
      </ModalComponent>
    );
  }
});
