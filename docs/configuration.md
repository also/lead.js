# Configuration

```
github:
  githubs:
    'github.example.com':
      api_base_url: 'https://github.example.com/api/v3'
      requires_access_token: true
      access_token: 'access_token'
  default: 'github.example.com'

server:
  base_url: 'http://graphite.example.com'

opentsdb:
  base_url: 'http://opentsdb.example.com'

app:
  intro_command: 'intro'
  publicUrl: 'http://cdn.example.com/'
  paths:
    also:
      site: 'github.com'
      repo: 'also/lead.js'

editor:
  keymap:
    notebook:
      'Ctrl-1': 'nb_run'
```
