import URI from 'URIjs';
import _ from 'underscore';
import Q from 'q';
import Router from 'react-router';
import React from 'react';
import * as Modules from '../modules';
import * as  Http from '../http';
import * as  Context from '../context';
import * as  Builtins from '../builtins';
import GistLinkComponent from './gistLinkComponent';
import EnsureAccessComponent from './EnsureAccessComponent';
import GitHubOAuthComponent from './oauthComponent';
import * as  Modal from '../modal';
import * as  Notebook from '../notebook';
import * as  Settings from '../settings';


const settings = Settings.with_prefix('server');

function get_site_from_url(url) {
  let host;
  const uri = new URI(url);
  const hostname = uri.hostname();

  if (hostname === 'gist.github.com' || hostname === 'api.github.com') {
    host = 'github.com';
  } else {
    host = hostname;
  }

  return get_site(host);
}

function _default() {
  return settings.get('default');
}

export {_default as default};

function get_site(name) {
  const site = settings.get('githubs', name != null ? name : settings.get('default'));

  if (site != null) {
    return Object.assign({domain: name}, site);
  }
}

function get_repo_contents(url) {
  return Http.get(url).then((response) => {
    return {
      content: atob(response.content.replace(/\n/g, '')),
      filename: response.name,
      type: 'application/octet-stream',
      base_href: response.html_url.replace('/blob/', '/raw/')
    };
  });
}

/** @private */
export function to_repo_url(path) {
  path = path.toString();
  if (path.indexOf('http') !== 0) {
    const site = get_site();
    if (path[0] === '/') {
      path = path.substr(1);
    }
    const [user, repo, ...segments] = path.split('/');
    return to_api_url(site, '/repos/' + user + '/' + repo + '/contents/' + segments.join('/'));
  } else {
    const site = get_site_from_url(path);
    if (path.indexOf(site.api_base_url) === 0) {
      return new URI(path);
    } else {
      const uri = new URI(path);

      path = uri.pathname();
      if (path[0] === '/') {
        path = path.substr(1);
      }
      const [user, repo, , ref, ...segments] = path.split('/');
      return to_api_url(site, '/repos/' + user + '/' + repo + '/contents/' + segments.join('/'), {ref: ref});
    }
  }
}

function save_gist(gist, options) {
  if (options == null) {
    options = {};
  }
  const site = get_site(options.github);

  return Http.post(to_api_url(site, '/gists'), gist);
}

function update_gist(id, gist, options) {
  if (options == null) {
    options = {};
  }
  const site = get_site(options.github);

  return Http.patch(to_api_url(site, '/gists/' + id), gist);
}

export function to_api_url(site, path, params) {
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
export function to_gist_url(gist) {
  const buildUrl = (site, id) => to_api_url(site, '/gists/' + id);

  gist = gist.toString();
  if (gist.indexOf('http') !== 0) {
    const site = get_site();
    return buildUrl(site, gist);
  } else {
    const site = get_site_from_url(gist);
    if (site != null) {
      const [id] = new URI(gist).filename().split('.');
      return buildUrl(site, id);
    } else {
      return new URI(gist);
    }
  }
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
    ? get_site_from_url(props.url)
    : get_site(_default())

  if (site.requires_access_token && site.access_token == null) {
    const deferred = Q.defer();

    const modal = Modal.pushModal({
      handler: EnsureAccessComponent,
      props: Object.assign({deferred, site}, props)
    });

    deferred.promise.finally(() => Modal.removeModal(modal));

    return deferred.promise;
  } else {
    return Q.resolve();
  }
}

export {GitHubOAuthComponent};

Modules.export(exports, 'github', ({componentFn, componentCmd}) => {
  settings.set('githubs', 'github.com', 'api_base_url', 'https://api.github.com');
  settings.default('default', 'github.com');

  componentFn('load', 'Loads a file from GitHub', (ctx, path, options={}) => {
    let url = to_repo_url(path);

    const promise = ensureAuth(ctx, {url: url})
    .then(() => {
      url = to_repo_url(path);
      return get_repo_contents(url).fail((response) => {
        return Q.reject(response.statusText);
      });
    }).then((file) => {
      return Notebook.handle_file(ctx, file, options);
    });

    return (
      <div>
        <Context.AsyncComponent promise={promise}>
          <Builtins.ComponentAndError promise={promise}>
            Loading file {path}
          </Builtins.ComponentAndError>
        </Context.AsyncComponent>
        <Builtins.PromiseStatusComponent promise={promise} start_time={new Date()}/>
      </div>
    );
  });

  componentCmd('gist', 'Loads a script from a gist', (ctx, gist, options={}) => {
    const url = to_gist_url(gist);
    const gistPromise = ensureAuth(ctx, {url: url})
    .then(() => {
      return Http.get(to_gist_url(gist)).fail((response) => {
        return Q.reject(response.statusText);
      });
    });

    const promise = gistPromise.then((response) => {
      const results = [];

      for (const name in response.files) {
        const file = response.files[name];

        results.push(Notebook.handle_file(ctx, file, options));
      }

      return results;
    });

    return (
      <div>
        <Context.AsyncComponent promise={promise}>
          <Builtins.ComponentAndError promise={promise}>
            Loading gist {gist}
            <Builtins.PromiseResolvedComponent constructor={GistLinkComponent} promise={gistPromise.then((r) => ({gist: r}))}/>
          </Builtins.ComponentAndError>
        </Context.AsyncComponent>
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
        return update_gist(id, gist);
      } else {
        return save_gist(gist);
      }
    }).fail(() => {
      return Q.reject('Save failed. Make sure your access token is configured correctly.');
    }).then((response) => ({gist: response}));

    return () => (
      <div>
        <Context.AsyncComponent promise={promise}>
          <Builtins.ComponentAndError promise={promise}>
            Saving gist
            <Builtins.PromiseResolvedComponent constructor={NotebookGistLinkComponent} promise={promise}/>
          </Builtins.ComponentAndError>
        </Context.AsyncComponent>
        <Builtins.PromiseStatusComponent promise={promise} start_time={new Date()}/>
      </div>
    );
  });
});
