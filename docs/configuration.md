# Configuration

```
github:
  githubs:
    'github.example.com':
      api_base_url: 'https://github.example.com/api/v3'
      requires_access_token: true
      access_token: 'access_token'
  default: 'github.example.com'

graphite:
  base_url: 'http://graphite.example.com'

opentsdb:
  base_url: 'http://opentsdb.example.com'

app:
  intro_command: 'intro'
  paths:
    also:
      site: 'github.com'
      repo: 'also/lead.js'
```
