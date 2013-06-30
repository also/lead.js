define (require) ->
  github = require 'github'

  describe 'github', ->
    it 'converts numbers to gist api urls', ->
      gist_url = github.to_gist_url 42
      expect(gist_url).toBe 'https://api.github.com/gists/42'

    it 'converts simple string to gist api urls', ->
      gist_url = github.to_gist_url '42'
      expect(gist_url).toBe 'https://api.github.com/gists/42'

    it 'converts gist urls to gist api urls', ->
      # https
      gist_url = github.to_gist_url 'https://gist.github.com/422'
      expect(gist_url).toBe 'https://api.github.com/gists/422'

      # http
      gist_url = github.to_gist_url 'http://gist.github.com/422'
      expect(gist_url).toBe 'https://api.github.com/gists/422'

    it 'converts gist repository urls to gist api urls', ->
      gist_url = github.to_gist_url 'https://gist.github.com/5794205.git'
      expect(gist_url).toBe 'https://api.github.com/gists/5794205'

    it 'handles gist api urls', ->
      gist_url = github.to_gist_url 'http://api.github.com/gists/5794205'
      expect(gist_url).toBe 'https://api.github.com/gists/5794205'
