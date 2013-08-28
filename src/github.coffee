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
  modules = require 'modules'
  http = require 'http'

  notebook = null
  require ['notebook'], (nb) ->
    notebook = nb

  {fn, cmd, context_fns, settings} = modules.create 'github'

  settings.set 'githubs', 'github.com', 'api_base_url', 'https://api.github.com'
  settings.default 'default', 'github.com'

  github =
    context_fns: context_fns
    get_github: (uri) ->
      hostname = uri.hostname()
      if hostname == 'gist.github.com' or hostname == 'api.github.com'
        host = 'github.com'
      else
        host = hostname

      settings.get 'githubs', host

    default: -> settings.get 'default'

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
        uri = URI gist
        site = github.get_github uri

        if github?
          [id, rest...] = uri.filename().split '.'
          build_url site, id
        else
          gist


  cmd 'gist', 'Loads a script from a gist', (gist, options={}) ->
    if arguments.length is 0
      @fns.save_gist()
    else
      url = github.to_gist_url gist
      @async ->
        @fns.text "Loading gist #{gist}"
        promise = http.get url
        promise.done (response) =>
          for name, file of response.files
            notebook.handle_file @, file, options
        promise.fail (response, status_text, error) =>
          @fns.error status_text

  cmd 'save_gist', 'Saves a notebook as a gist', ->
    notebook = @export_notebook()
    gist =
      public: true
      files:
        'notebook.lnb':
          content: JSON.stringify notebook, undefined, 2
    @async ->
      promise = github.save_gist gist
      promise.done (result) =>
        @fns.html "<a href='#{result.html_url}'>#{result.html_url}</a>"
        lead_uri = URI window.location.href
        lead_uri.fragment "/#{result.html_url}"
        @fns.html "<a href='#{lead_uri}'>#{lead_uri}</a>"
      promise.fail =>
        @fns.error 'Save failed. Make sure your access token is configured correctly.'

  github
