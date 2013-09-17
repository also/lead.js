# types of githubs
#
# github.com
#   gist.github.com/also/5794205
#   gist.github.com/5794205.git
#   api.github.com/gists/5794205
#
# git.example.com
#   git.example.com/gist/1051
#   git.example.com/api/v3/gists/1051?access_token=...

define (require) ->
  URI = require 'URIjs'
  Q = require 'q'
  modules = require 'modules'
  http = require 'http'
  global_settings = require 'settings'

  notebook = null
  require ['notebook'], (nb) ->
    notebook = nb

  modules.create 'github', ({fn, cmd, settings}) ->
    settings.set 'githubs', 'github.com', 'api_base_url', 'https://api.github.com'
    settings.default 'default', 'github.com'

    github =
      get_github: (url) ->
        uri = URI url
        hostname = uri.hostname()
        if hostname == 'gist.github.com' or hostname == 'api.github.com'
          host = 'github.com'
        else
          host = hostname

        settings.get 'githubs', host

      default: -> settings.get 'default'

      get_repo_contents: (url) ->
        http.get(url)
        .then (response) ->
          file =
            content: atob response.content.replace /\n/g, ''
            filename: response.name
            type: 'application/octet-stream'

      to_repo_url: (path) ->
        path = path.toString()
        if path.indexOf('http') != 0
          site = settings.get 'githubs', github.default()
          path = path.substr 1 if path[0] == '/'
          [user, repo, segments...] = path.split '/'
          url = "#{site.api_base_url}/repos/#{user}/#{repo}/contents/#{segments.join '/'}"
        else
          site = github.get_github path
          if path.indexOf(site.api_base_url) == 0
            url = path
          else
            uri = URI path
            path = uri.pathname()
            path = path.substr 1 if path[0] == '/'
            [user, repo, x, ref, segments...] = path.split '/'
            url = "#{site.api_base_url}/repos/#{user}/#{repo}/contents/#{segments.join '/'}?ref=#{ref}"

      save_gist: (gist, options={}) ->
        github_host = options.github ? github.default()
        gh = settings.get 'githubs', github_host
        http.post "#{gh.api_base_url}/gists?access_token=#{gh.access_token}", gist

      to_gist_url: (gist) ->
        build_url = (site, id) ->
          url = site.api_base_url + "/gists/#{id}"
          if site.access_token
            url += "?access_token=#{site.access_token}"
          url
        gist = gist.toString()
        if gist.indexOf('http') != 0
          site = settings.get 'githubs', github.default()
          build_url site, gist
        else
          site = github.get_github gist

          if github?
            [id, rest...] = URI(gist).filename().split '.'
            build_url site, id
          else
            gist

    cmd 'load', 'Loads a file from GitHub', (path, options={}) ->
      url = github.to_repo_url path
      ensure_access @, url
      @async ->
        @text "Loading file #{path}"
        promise = github.get_repo_contents(url)
        .then (file) =>
          notebook.handle_file @, file, options
        promise.fail (response) =>
          @error response.statusText
        promise

    ensure_access = (ctx, url) ->
      unless url?
        instance = settings.get 'githubs', github.default()
      else
        instance = github.get_github url
      if instance? and instance.requires_access_token and not instance.access_token?
        result = Q.defer()
        ctx.text 'Please set a GitHub access token:'
        input = ctx.input.text_input()
        button = ctx.input.button('Save')
        button.map(input).onValue (access_token) ->
          domain = URI(url).hostname()
          global_settings.user_settings.set 'github', 'githubs', domain, 'access_token', access_token
          result.resolve()
        result.promise
      else
        Q true

    cmd 'gist', 'Loads a script from a gist', (gist, options={}) ->
      if arguments.length is 0
        @github.save_gist()
      else
        url = github.to_gist_url gist
        @async ->
          authorized = ensure_access @, url
          authorized.then =>
            @text "Loading gist #{gist}"
            promise = http.get url
            promise.done (response) =>
              for name, file of response.files
                notebook.handle_file @, file, options
            promise.fail (response) =>
              @error response.statusText

    cmd 'save_gist', 'Saves a notebook as a gist', ->
      notebook = @export_notebook()
      gist =
        public: true
        files:
          'notebook.lnb':
            content: JSON.stringify notebook, undefined, 2
      @async ->
        authorized = ensure_access @
        authorized.then =>
          promise = github.save_gist gist
          promise.done (result) =>
            @html "<a href='#{result.html_url}'>#{result.html_url}</a>"
            lead_uri = URI window.location.href
            lead_uri.fragment "/#{result.html_url}"
            @html "<a href='#{lead_uri}'>#{lead_uri}</a>"
          promise.fail =>
            @error 'Save failed. Make sure your access token is configured correctly.'

    github
