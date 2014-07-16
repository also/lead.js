expect = require 'expect.js'
github = require '../github'

describe 'github', ->
  it 'converts numbers to gist api urls', ->
    gist_url = github.to_gist_url 42
    expect(gist_url.toString()).to.be 'https://api.github.com/gists/42'

  it 'converts simple string to gist api urls', ->
    gist_url = github.to_gist_url '42'
    expect(gist_url.toString()).to.be 'https://api.github.com/gists/42'

  it 'converts gist urls to gist api urls', ->
    # https
    gist_url = github.to_gist_url 'https://gist.github.com/422'
    expect(gist_url.toString()).to.be 'https://api.github.com/gists/422'

    # http
    gist_url = github.to_gist_url 'http://gist.github.com/422'
    expect(gist_url.toString()).to.be 'https://api.github.com/gists/422'

  it 'converts gist repository urls to gist api urls', ->
    gist_url = github.to_gist_url 'https://gist.github.com/5794205.git'
    expect(gist_url.toString()).to.be 'https://api.github.com/gists/5794205'

  it 'handles gist api urls', ->
    gist_url = github.to_gist_url 'http://api.github.com/gists/5794205'
    expect(gist_url.toString()).to.be 'https://api.github.com/gists/5794205'

  it 'handles repo contents api urls', ->
    url = 'https://api.github.com/repos/also/lead.js/contents/examples/colors.coffee?ref=1f2c7e04666cd2fc5460805ca884faf25c1074b2'
    repo_url = github.to_repo_url url
    expect(repo_url.toString()).to.be url

  it 'converts html urls to api urls', ->
    url = 'https://github.com/also/lead.js/blob/master/examples/browser.coffee'
    repo_url = github.to_repo_url url
    expect(repo_url.toString()).to.be 'https://api.github.com/repos/also/lead.js/contents/examples/browser.coffee?ref=master'

  it 'converts paths to api urls', ->
    path = 'also/lead.js/examples/browser.coffee'
    repo_url = github.to_repo_url path
    expect(repo_url.toString()).to.be 'https://api.github.com/repos/also/lead.js/contents/examples/browser.coffee'
