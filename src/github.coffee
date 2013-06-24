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

define ['lib/URI'], (URI) ->
  github =
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
      github = github.githubs[github_host]
      $.ajax
        url: "#{github.api_base_url}/gists?access_token=#{github.access_token}"
        type: 'post'
        contentType: 'application/json'
        data: JSON.stringify gist
        success: options.success
        error: options.error

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
          [id, _...] = uri.filename().split '.'
          build_url site, id
        else
          gist