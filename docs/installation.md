# Installation

Download a release from https://github.com/also/lead.js/releases, or check out the repository and build from source.

You'll want to customize the settings in `config.js`, or you won't be able to graph anything:

```javascript
settings.set('graphite', 'base_url', 'http://graphite.example.com');
settings.set('github', 'githubs', 'github.example.com', {api_base_url: 'https://github.example.com/api/v3', requires_access_token: true});
```

Now, installing lead.js is just placing these files on a server somewhere. You'll need to configure your Graphite, OpenTSDB, and any other data sources to allow CORS access to this origin.

## Building from source

Building lead.js requires **node.js**, **npm**, **Ruby** and **Bundler**.
With these installed,

```
npm install
bundle install --path vendor
```

Build with

```
grunt
```

This will produce a `dist` directory containing all the files necessary to run lead.js:

```
config.js
index.html
lead-app.js
require.js
style.css
```
