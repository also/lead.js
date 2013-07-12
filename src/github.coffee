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
  URI = require 'lib/URI'
  $ = require 'jquery'
  modules = require 'modules'

  notebook = null
  require ['notebook'], (nb) ->
    notebook = nb

  {fn, cmd, ops} = modules.create()

  github =
    ops: ops
    githubs:
      'github.com':
        api_base_url: 'https://api.github.com'

    get_github: (uri) ->
      hostname = uri.hostname()
      if hostname == 'gist.github.com' or hostname == 'api.github.com'
        github.githubs['github.com']
      else
        github.githubs[hostname]

    default: 'github.com'

    save_gist: (gist, options={}) ->
      github_host = options.github ? github.default
      gh = github.githubs[github_host]
      $.ajax
        url: "#{gh.api_base_url}/gists?access_token=#{gh.access_token}"
        type: 'post'
        contentType: 'application/json'
        data: JSON.stringify gist

    to_gist_url: (gist) ->
      build_url = (site, id) ->
        url = site.api_base_url + "/gists/#{id}"
        if site.access_token
          url += "?access_token=#{site.access_token}"
        url
      gist = gist.toString()
      if gist.indexOf('http') != 0
        site = github.githubs[github.default]
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
      @cli.save_gist()
    else
      url = github.to_gist_url gist
      @async ->
        @cli.text "Loading gist #{gist}"
        promise = $.ajax
          type: 'GET'
          url: url
          dataType: 'json'
        promise.done (response) =>
          for name, file of response.files
            notebook.handle_file @, file, options
        promise.fail (response, status_text, error) =>
          @cli.error status_text

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
        @cli.html "<a href='#{result.html_url}'>#{result.html_url}</a>"
        lead_uri = URI window.location.href
        lead_uri.fragment "/#{result.html_url}"
        @cli.html "<a href='#{lead_uri}'>#{lead_uri}</a>"
      promise.fail =>
        @cli.error 'Save failed. Make sure your access token is configured correctly.'

  github
