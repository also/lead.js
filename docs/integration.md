# Integrating your own modules into lead.js

You can add your own modules, routes, etc. by extending the webpack configuration to build them.

The easiest way to do this is to add lead.js as a Git submodule to your project and create your own `webpack.config.js` and entry file `main.coffee` (or `main.js`):

```javascript
var config = require('./lead.js/webpack.config.js').integrate(__dirname);

config.entry = {'my-integration': __dirname + '/main'};

config.output.path = __dirname + '/build'

module.exports = config;
```

This will create a `build` directory containing `lead-my-integration.js` and all other required files.

Inside `main.coffee`, you can require lead.js modules and configure and start the application.

```coffeescript
document.title = 'my lead.js integration'

require "!style!css!sass!./lead.js/app/style.scss"

app = require './lead.js/app/app'
# a file containing your own lead.js settings, for example
require './config'

app.initApp document.body,
  extraRoutes: require('./myRoutes')
```
