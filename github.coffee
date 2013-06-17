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

lead.github =
  githubs:
    'github.com':
      api_base_url: 'https://api.github.com'

  get_github: (uri) ->
    hostname = uri.hostname()
    if hostname == 'gist.github.com' or hostname == 'api.github.com'
      lead.github.githubs['github.com']
    else
      lead.github.githubs[hostname]

  default: 'github.com'

  to_gist_url: (gist) ->
    build_url = (github, id) ->
      url = github.api_base_url + "/gists/#{id}"
      if github.access_token
        url += "?access_token=#{github.access_token}"
      url
    gist = gist.toString()
    if gist.indexOf('http') != 0
      github = lead.github.githubs[lead.github.default]
      build_url github, gist
    else
      uri = URI gist
      github = lead.github.get_github uri

      if github?
        [id, _...] = uri.filename().split '.'
        build_url github, id
      else
        gist