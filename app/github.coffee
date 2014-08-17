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
moment = require 'moment'
React = require 'react'
Bacon = require 'bacon.model'
modules = require './modules'
http = require './http'
global_settings = require './settings'
Context = require './context'
Builtins = require './builtins'

Notebook = require './notebook'

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
      http.get(url)
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
      http.post github.to_api_url(site, '/gists'), gist

    update_gist: (id, gist, options={}) ->
      site = github.get_site options.github
      http.patch github.to_api_url(site, "/gists/#{id}"), gist

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

  component_fn 'load', 'Loads a file from GitHub', (ctx, path, options={}) ->
    url = github.to_repo_url path
    deferred = Q.defer()
    promise = deferred.promise.then ->
      github.get_repo_contents url
    .fail (response) ->
      Q.reject response.statusText
    .then (file) ->
      Notebook.handle_file ctx, file, options

    EnsureAccessComponent {url, on_access: deferred.resolve},
      Context.AsyncComponent {promise},
        Builtins.ComponentAndError {promise},
          "Loading file #{path}"
      Builtins.PromiseStatusComponent {promise, start_time: new Date}

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
        React.DOM.p null,
          'lead.js requires an access token to use the GitHub API. You can create a '
          React.DOM.a {href: 'https://github.com/blog/1509-personal-api-tokens', target: '_blank'}, 'personal access token'
          # TODO just link to the settings
          ' in the "Personal access tokens" section of your GitHub account "Applications" settings.'

  EnsureAccessComponent = React.createClass
    displayName: 'EnsureAccessComponent'
    mixins: [Context.ContextAwareMixin]
    getDefaultProps: ->
      on_access: ->
    getInitialState: ->
      # FIXME #175 props can change
      if @props.url?
        site = github.get_site_from_url @props.url
      else if @props.site?
        site = @props.site
      else
        site = github.get_site github.default()

      if (site.requires_access_token or @props.require_access_token) and not site.access_token?
        tokens = new Bacon.Bus
        user_details = tokens.flatMapLatest (access_token) =>
          @setState token_status: 'validating'
          Bacon.combineTemplate
            user: Bacon.fromPromise http.get github.to_api_url(site, '/user').setQuery {access_token}
            access_token: access_token
          .changes()
        user_details.onValue ({user, access_token}) =>
          global_settings.user_settings.set 'github', 'githubs', site.domain, 'access_token', access_token
          @props.on_access()
          @setState user: user, token_status: 'valid'
        user_details.onError =>
          @setState token_status: 'invalid'

        token_status: 'needed'
        user: null
        tokens: tokens
        site: site
      else
        @props.on_access()

        token_status: 'skip'
    render: ->
      if @state.token_status == 'skip'
        React.DOM.div null, @props.children
      else
        message = switch @state.token_status
          when 'needed' then React.DOM.strong null, 'You need to set a GitHub access token'
          when 'validating' then React.DOM.strong null, 'Validating your token'
          when 'valid' then React.DOM.strong null, 'Logged in as ', @state.user.name
          when 'invalid' then React.DOM.strong null, "That access token didn't work. Try again?"
        React.DOM.div null,
          React.DOM.p null, message
          if @state.token_status == 'valid'
            @props.children
          else
            AccessTokenForm
              site: @state.site,
              require_access_token: @props.require_access_token
              handle_token: (t) => @state.tokens.push t

  component_cmd 'gist', 'Loads a script from a gist', (ctx, gist, options={}) ->
    url = github.to_gist_url gist

    deferred = Q.defer()
    gist_promise = deferred.promise.then ->
      http.get url
    .fail (response) ->
      Q.reject response.statusText
    promise = gist_promise
    .then (response) ->
      for name, file of response.files
        Notebook.handle_file ctx, file, options

    EnsureAccessComponent {url, on_access: deferred.resolve},
      Context.AsyncComponent {promise},
        Builtins.ComponentAndError {promise},
          "Loading gist #{gist}"
          Builtins.PromiseResolvedComponent
            constructor: GistLinkComponent
            promise: gist_promise.then (r) -> gist: r
      Builtins.PromiseStatusComponent {promise, start_time: new Date}

  GistLinkComponent = React.createClass
    render: ->
      avatar = @props.gist.user?.avatar_url ? 'https://github.com/images/gravatars/gravatar-user-420.png'
      username = @props.gist.user?.login ? 'anonymous'
      filenames = _.keys @props.gist.files
      filenames.sort()
      if filenames[0] == 'gistfile1.txt'
        title = "gist:#{@props.gist.id}"
      else
        title = filenames[0]
      React.DOM.div {className: 'gist-link'}, [
        React.DOM.img {src: avatar}
        if @props.gist.user?
          React.DOM.a {href: @props.gist.user.html_url, target: '_blank'}, username
        else
          username
        ' / '
        React.DOM.a {href: @props.gist.html_url, target: '_blank'}, title
        React.DOM.span {className: 'datetime'}, "Saved #{moment(@props.gist.updated_at).fromNow()}"
      ]

  NotebookGistLinkComponent = React.createClass
    render: ->
      lead_uri = URI window.location.href
      lead_uri.query null
      lead_uri.fragment "/#{@props.gist.html_url}"
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

    deferred = Q.defer()
    promise = deferred.promise.then ->
      if id?
        github.update_gist id, gist
      else
        github.save_gist gist
    .fail (response) ->
      Q.reject 'Save failed. Make sure your access token is configured correctly.'
    .then (response) ->
      gist: response

    EnsureAccessComponent {on_access: deferred.resolve},
      Context.AsyncComponent {promise},
        Builtins.ComponentAndError {promise},
          "Saving gist"
          Builtins.PromiseResolvedComponent
            constructor: NotebookGistLinkComponent
            promise: promise
      Builtins.PromiseStatusComponent {promise, start_time: new Date}

  github
