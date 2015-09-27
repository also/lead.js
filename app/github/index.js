import URI from 'urijs';
import Q from 'q';
import Router from 'react-router';
import React from 'react';
import * as Modules from '../modules';
import * as  Http from '../http';
import AsyncComponent from '../context/AsyncComponent';
import * as  Builtins from '../builtins';
import GistLinkComponent from './GistLinkComponent';
import EnsureAccessComponent from './EnsureAccessComponent';
import GitHubOAuthComponent from './OAuthComponent';
import * as  Modal from '../modal';
import * as  Notebook from '../notebook';


function getSite(ctx, name) {
  const settings = ctx.settings.global.with_prefix('github');
  if (!name) {
    name = settings.get('default');
  }

  const site = settings.get('githubs', name);

  if (site != null) {
    return Object.assign({domain: name}, site);
  }
}

function getSiteFromUrl(ctx, url) {
  let host;
  const uri = new URI(url);
  const hostname = uri.hostname();

  if (hostname === 'gist.github.com' || hostname === 'api.github.com') {
    host = 'github.com';
  } else {
    host = hostname;
  }

  return getSite(ctx, host);
}

/** @protected (github/*.js only) */
export function toApiUrl(ctx, site, path, params) {
  if (params == null) {
    params = {};
  }
  const result = new URI('' + site.api_base_url + path).setQuery(params);

  if (site.access_token != null) {
    result.setQuery('access_token', site.access_token);
  }
  return result;
}

/** @private */
export function toGistUrl(ctx, gist) {
  const buildUrl = (site, id) => toApiUrl(ctx, site, '/gists/' + id);

  gist = gist.toString();
  if (gist.indexOf('http') !== 0) {
    const site = getSite(ctx);
    return buildUrl(site, gist);
  } else {
    const site = getSiteFromUrl(ctx, gist);
    if (site != null) {
      const [id] = new URI(gist).filename().split('.');
      return buildUrl(site, id);
    } else {
      return new URI(gist);
    }
  }
}

function getRepoContents(ctx, url) {
  return Http.get(ctx, url).then((response) => {
    return {
      content: atob(response.content.replace(/\n/g, '')),
      filename: response.name,
      type: 'application/octet-stream',
      base_href: response.html_url.replace('/blob/', '/raw/')
    };
  });
}

/** @private */
export function toRepoUrl(ctx, path) {
  path = path.toString();
  if (path.indexOf('http') !== 0) {
    const site = getSite(ctx);
    if (path[0] === '/') {
      path = path.substr(1);
    }
    const [user, repo, ...segments] = path.split('/');
    return toApiUrl(ctx, site, '/repos/' + user + '/' + repo + '/contents/' + segments.join('/'));
  } else {
    const site = getSiteFromUrl(ctx, path);
    if (path.indexOf(site.api_base_url) === 0) {
      return new URI(path);
    } else {
      const uri = new URI(path);

      path = uri.pathname();
      if (path[0] === '/') {
        path = path.substr(1);
      }
      const [user, repo, , ref, ...segments] = path.split('/');
      return toApiUrl(ctx, site, '/repos/' + user + '/' + repo + '/contents/' + segments.join('/'), {ref: ref});
    }
  }
}

function saveGist(ctx, gist, options) {
  if (options == null) {
    options = {};
  }
  const site = getSite(ctx, options.github);

  return Http.post(ctx, toApiUrl(ctx, site, '/gists'), gist);
}

function updateGist(ctx, id, gist, options) {
  if (options == null) {
    options = {};
  }
  const site = getSite(ctx, options.github);

  return Http.patch(ctx, toApiUrl(toApiUrl, site, '/gists/' + id), gist);
}

const NotebookGistLinkComponent = React.createClass({
  mixins: [Router.Navigation],
  render() {
    const leadUri = new URI(window.location.href);

    leadUri.query(null);
    leadUri.fragment(this.makeHref('gist_notebook', {
      splat: this.props.gist.html_url
    }));

    return (
      <div>
        <GistLinkComponent gist={this.props.gist}/>
        <p><a href={leadUri}>{leadUri.toString()}</a></p>
      </div>
    );
  }
});

function ensureAuth(ctx, props={}) {
  const site = props.url
    ? getSiteFromUrl(ctx, props.url)
    : getSite(ctx)

  if (site.requires_access_token && site.access_token == null) {
    const deferred = Q.defer();

    const modal = Modal.pushModal(ctx, {
      handler: EnsureAccessComponent,
      props: Object.assign({deferred, site, ctx, onAccess: deferred.resolve, onCancel: deferred.reject}, props)
    });

    deferred.promise.finally(() => Modal.removeModal(ctx, modal));

    return deferred.promise;
  } else {
    return Q.resolve();
  }
}

export {GitHubOAuthComponent};

Modules.export(exports, 'github', ({componentFn, componentCmd, settings}) => {
  settings.set('githubs', 'github.com', 'api_base_url', 'https://api.github.com');
  settings.default('default', 'github.com');

  componentFn('load', 'Loads a file from GitHub', (ctx, path, options={}) => {
    let url = toRepoUrl(ctx, path);

    const promise = ensureAuth(ctx, {url: url})
    .then(() => {
      url = toRepoUrl(ctx, path);
      return getRepoContents(ctx, url).fail((response) => {
        return Q.reject(response.statusText);
      });
    }).then((file) => {
      Notebook.handle_file(ctx, file, options);
    });

    return (
      <div>
        <AsyncComponent promise={promise}>
          <Builtins.ComponentAndError promise={promise}>
            Loading file {path}
          </Builtins.ComponentAndError>
        </AsyncComponent>
        <Builtins.PromiseStatusComponent promise={promise} start_time={new Date()}/>
      </div>
    );
  });

  componentCmd('gist', 'Loads a script from a gist', (ctx, gist, options={}) => {
    const url = toGistUrl(ctx, gist);
    const gistPromise = ensureAuth(ctx, {url: url})
    .then(() => {
      return Http.get(ctx, toGistUrl(ctx, gist)).fail((response) => {
        return Q.reject(response.statusText);
      });
    });

    const promise = gistPromise.then((response) => {
      for (const name in response.files) {
        const file = response.files[name];
        Notebook.handle_file(ctx, file, options);
      }
    });

    return (
      <div>
        <AsyncComponent promise={promise}>
          <Builtins.ComponentAndError promise={promise}>
            Loading gist {gist}
            <Builtins.PromiseResolvedComponent constructor={GistLinkComponent} promise={gistPromise.then((r) => ({gist: r}))}/>
          </Builtins.ComponentAndError>
        </AsyncComponent>
        <Builtins.PromiseStatusComponent promise={promise} start_time={new Date()}/>
      </div>
    );
  });

  componentCmd('save_gist', 'Saves a notebook as a gist', (ctx, id) => {
    const notebook = ctx.exportNotebook();
    const gist = {
      public: true,
      files: {
        'notebook.lnb': {
          content: JSON.stringify(notebook, null, 2)
        }
      }
    };

    const promise = ensureAuth(ctx).then(() => {
      if (id != null) {
        return updateGist(ctx, id, gist);
      } else {
        return saveGist(ctx, gist);
      }
    }).fail(() => {
      return Q.reject('Save failed. Make sure your access token is configured correctly.');
    }).then((response) => ({gist: response}));

    return () => (
      <div>
        <AsyncComponent promise={promise}>
          <Builtins.ComponentAndError promise={promise}>
            Saving gist
            <Builtins.PromiseResolvedComponent constructor={NotebookGistLinkComponent} promise={promise}/>
          </Builtins.ComponentAndError>
        </AsyncComponent>
        <Builtins.PromiseStatusComponent promise={promise} start_time={new Date()}/>
      </div>
    );
  });
});
