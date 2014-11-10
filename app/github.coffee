# types of github urls
#
# github.com
#   gist.github.com/also/5794205
#   gist.github.com/5794205.git
#   api.github.com/gists/5794205
#
# git.example.com
#   git.example.com/gist/1051
#   git.example.com/api/v3/gists/1051?access_token=...

URI = require 'URIjs'
_ = require 'underscore'
Q = require 'q'
Router = require 'react-router'
moment = require 'moment'
React = require 'react'
Bacon = require 'bacon.model'
modules = require './modules'
Http = require './http'
global_settings = require './settings'
Context = require './context'
ContextComponents = require './contextComponents'
Builtins = require './builtins'
App = require './app'

Notebook = require './notebook'
Server = require './server'

modules.export exports, 'github', ({component_fn, component_cmd, fn, cmd, settings}) ->
  settings.set 'githubs', 'github.com', 'api_base_url', 'https://api.github.com'
  settings.default 'default', 'github.com'

  github =
    get_site_from_url: (url) ->
      uri = URI url
      hostname = uri.hostname()
      if hostname == 'gist.github.com' or hostname == 'api.github.com'
        host = 'github.com'
      else
        host = hostname

      github.get_site host

    default: -> settings.get 'default'
    get_site: (name) ->
      site = settings.get 'githubs', name ? settings.get 'default'
      if site?
        _.extend {domain: name}, site

    get_repo_contents: (url) ->
      Http.get(url)
      .then (response) ->
        file =
          content: atob response.content.replace /\n/g, ''
          filename: response.name
          type: 'application/octet-stream'
          base_href: response.html_url.replace '/blob/', '/raw/'

    to_repo_url: (path) ->
      path = path.toString()
      if path.indexOf('http') != 0
        site = github.get_site()
        path = path.substr 1 if path[0] == '/'
        [user, repo, segments...] = path.split '/'
        url = github.to_api_url site, "/repos/#{user}/#{repo}/contents/#{segments.join '/'}"
      else
        site = github.get_site_from_url path
        if path.indexOf(site.api_base_url) == 0
          url = URI path
        else
          uri = URI path
          path = uri.pathname()
          path = path.substr 1 if path[0] == '/'
          [user, repo, x, ref, segments...] = path.split '/'
          url = github.to_api_url site, "/repos/#{user}/#{repo}/contents/#{segments.join '/'}", {ref}

    save_gist: (gist, options={}) ->
      site = github.get_site options.github
      Http.post github.to_api_url(site, '/gists'), gist

    update_gist: (id, gist, options={}) ->
      site = github.get_site options.github
      Http.patch github.to_api_url(site, "/gists/#{id}"), gist

    to_api_url: (site, path, params={}) ->
      result = URI("#{site.api_base_url}#{path}").setQuery(params)
      result.setQuery('access_token', site.access_token) if site.access_token?
      result

    to_gist_url: (gist) ->
      build_url = (site, id) ->
        github.to_api_url site, "/gists/#{id}"
      gist = gist.toString()
      if gist.indexOf('http') != 0
        site = github.get_site()
        build_url site, gist
      else
        site = github.get_site_from_url gist

        if github?
          [id, rest...] = URI(gist).filename().split '.'
          build_url site, id
        else
          URI gist

    GitHubOAuthComponent: React.createClass
      getInitialState: ->
        promise = Http.post(Server.url('github/oauth/token'), @props.query)
        promise.finally => @setState finished: true
        promise.then (v) ->
          if v.access_token?
            global_settings.user_settings.set 'github', 'githubs', github.default(), 'access_token', v.access_token

        {promise}
      render: ->
        promiseState = @state.promise.inspect()
        if promiseState.state = 'fulfilled'
          footer = React.DOM.div {},
            React.DOM.button {onClick: -> window.close()}, 'OK'

        React.DOM.div {className: 'modal-bg'},
          React.DOM.div {className: 'modal-fg'},
            App.ModalComponent {footer, title: 'GitHub Authentication'},
              if @state.finished
                if promiseState.state = 'fulfilled'
                  if promiseState.value.access_token?
                    React.DOM.div {},
                      'You have successfully authorized lead to use GitHub'
                  else
                    if promiseState.value.error_description?
                      promiseState.value.error_description
                    else
                      'Unknown error'
                else
                  'Unknown error'
              else
                React.DOM.div {}, 'Authenticating with GitHub...'

  component_fn 'load', 'Loads a file from GitHub', (ctx, path, options={}) ->
    url = github.to_repo_url path
    promise = ensureAuth(ctx, {url}).then ->
      github.get_repo_contents url
    .fail (response) ->
      Q.reject response.statusText
    .then (file) ->
      Notebook.handle_file ctx, file, options

    React.DOM.div {},
      Context.AsyncComponent {promise},
        Builtins.ComponentAndError {promise},
          "Loading file #{path}"
      Builtins.PromiseStatusComponent {promise, start_time: new Date}

  ensureAuth = (ctx, props) ->
    if @props?.url
      site = github.get_site_from_url(@props.url)
    else
      site = github.get_site github.default()

    if site.requires_access_token and not site.access_token?
      deferred = Q.defer()
      modal = App.pushModal handler: EnsureAccessComponent, props: _.extend {deferred, site}, props
      deferred.promise.finally -> App.removeModal(modal)
      deferred.promise
    else
      Q.resolve()

  AccessTokenForm = React.createClass
    displayName: 'AccessTokenForm'
    handle_set: -> @props.handle_token @refs.input.getDOMNode().value
    render: ->
      React.DOM.div null,
        React.DOM.p null,
          # TODO use a friendlier url the the api base url
          "Please set a GitHub access token for #{@props.site.api_base_url}: "
          React.DOM.input ref: 'input'
          React.DOM.button {onClick: @handle_set}, 'Set'
        React.DOM.p {className: 'tip'},
          'lead.js requires an access token to use the GitHub API. You can create a '
          React.DOM.a {href: 'https://github.com/blog/1509-personal-api-tokens', target: '_blank'}, 'personal access token'
          # TODO just link to the settings
          ' in the "Personal access tokens" section of your GitHub account "Applications" settings.'

  EnsureAccessComponent = React.createClass
    displayName: 'EnsureAccessComponent'
    mixins: [ContextComponents.ContextAwareMixin]
    getInitialState: ->
      # FIXME #175 props can change
      site = @props.site
      tokens = new Bacon.Bus
      unsubscribe = tokens.plug(settings.toProperty('githubs', site.domain, 'access_token').filter(_.identity))
      user_details = tokens.flatMapLatest (access_token) =>
        @setState token_status: 'validating'
        Bacon.combineTemplate
          user: Bacon.fromPromise Http.get github.to_api_url(site, '/user').setQuery {access_token}
          access_token: access_token
        .changes()
      # TODO unsubscribe
      user_details.onValue ({user, access_token}) =>
        if global_settings.user_settings.get('github', 'githubs', site.domain, 'access_token') != access_token
          global_settings.user_settings.set 'github', 'githubs', site.domain, 'access_token', access_token
        @props.deferred.resolve()
        @setState user: user, token_status: 'valid'
      user_details.onError =>
        @setState token_status: 'invalid'

      token_status: 'needed'
      user: null
      tokens: tokens
      site: site
      unsubscribe: unsubscribe
    cancel: ->
      @props.deferred.reject()
    componentWillUnmount: ->
      @state.unsubscribe?()
    render: ->
      if @state.token_status == 'skip'
        # whoops, shouldn't have even rendered?
        null
      else
        message = switch @state.token_status
          when 'needed' then React.DOM.strong null, 'You need to set a GitHub access token'
          when 'validating' then React.DOM.strong null, 'Validating your token'
          when 'valid' then React.DOM.strong null, 'Logged in as ', @state.user.name
          when 'invalid' then React.DOM.strong null, "That access token didn't work. Try again?"

        footer = React.DOM.button {onClick: @cancel}, 'OK'
        App.ModalComponent {footer, title: 'GitHub Authentication'},
          React.DOM.a {href: Server.url('github/oauth/authorize'), target: '_blank'}, 'Log in to GitHub'
          # AccessTokenForm
          #   site: @state.site,
          #   handle_token: (t) => @state.tokens.push t
          # React.DOM.p null, message


  component_cmd 'gist', 'Loads a script from a gist', (ctx, gist, options={}) ->
    url = github.to_gist_url gist

    gist_promise = ensureAuth(ctx, {url}).then ->
      Http.get github.to_gist_url(gist)
    .fail (response) ->
      Q.reject response.statusText
    promise = gist_promise
    .then (response) ->
      for name, file of response.files
        Notebook.handle_file ctx, file, options

    React.DOM.div {},
      Context.AsyncComponent {promise},
        Builtins.ComponentAndError {promise},
          "Loading gist #{gist}"
          Builtins.PromiseResolvedComponent
            constructor: GistLinkComponent
            promise: gist_promise.then (r) -> gist: r
      Builtins.PromiseStatusComponent {promise, start_time: new Date}

  GistLinkComponent = React.createClass
    render: ->
      avatar = @props.gist.owner?.avatar_url ? 'https://github.com/images/gravatars/gravatar-user-420.png'
      username = @props.gist.owner?.login ? 'anonymous'
      filenames = _.keys @props.gist.files
      filenames.sort()
      if filenames[0] == 'gistfile1.txt'
        title = "gist:#{@props.gist.id}"
      else
        title = filenames[0]
      React.DOM.div {className: 'gist-link'},
        React.DOM.div {className: 'creator'},
          React.DOM.img {src: avatar}
          if @props.gist.user?
            React.DOM.a {href: @props.gist.user.html_url, target: '_blank'}, username
          else
            username
          ' / '
          React.DOM.a {href: @props.gist.html_url, target: '_blank'}, title
        React.DOM.span {className: 'datetime'}, "Saved #{moment(@props.gist.updated_at).fromNow()}"

  NotebookGistLinkComponent = React.createClass
    mixins: [Router.Navigation]
    render: ->
      lead_uri = URI window.location.href
      lead_uri.query null
      lead_uri.fragment @makeHref 'gist_notebook', splat: @props.gist.html_url
      React.DOM.div {}, [
        GistLinkComponent gist: @props.gist
        # TODO should this be target=_blank
        React.DOM.p {}, React.DOM.a {href: lead_uri}, lead_uri.toString()
      ]

  component_cmd 'save_gist', 'Saves a notebook as a gist', (ctx, id) ->
    notebook = ctx.export_notebook()
    gist =
      public: true
      files:
        'notebook.lnb':
          content: JSON.stringify notebook, undefined, 2

    promise = ensureAuth(ctx).then ->
      if id?
        github.update_gist id, gist
      else
        github.save_gist gist
    .fail (response) ->
      Q.reject 'Save failed. Make sure your access token is configured correctly.'
    .then (response) ->
      gist: response

    ->
      React.DOM.div {},
        Context.AsyncComponent {promise},
          Builtins.ComponentAndError {promise},
            "Saving gist"
            Builtins.PromiseResolvedComponent
              constructor: NotebookGistLinkComponent
              promise: promise
        Builtins.PromiseStatusComponent {promise, start_time: new Date}

  github
