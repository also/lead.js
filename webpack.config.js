webpack = require('webpack');

module.exports = {
  debug: true,
    context: __dirname + "/src",
    entry: "app_main",
    output: {
        path: __dirname + "/dist",
        filename: "lead-app.js"
    },
    externals: {
                 'jsdom': true
               },
    resolve: {
               root: [__dirname + '/src', __dirname + '/lib'],
               //modulesDirectories: [],
               extensions: ['', '.webpack.js', '.web.js', '.js', '.coffee'],
               alias: {
                 // i think this is necessary becase bacon.model references 'baconjs' in commonjs and 'bacon' in amd
                 'bacon': 'baconjs',
                 'cm/codemirror': 'codemirror-3.21/codemirror',
                 'cm/runmode': 'codemirror-3.21/runmode',
                 'cm/coffeescript': 'codemirror-3.21/coffeescript',
                 'cm/javascript': 'codemirror-3.21/javascript',
                 'cm/show-hint': 'codemirror-3.21/coffeescript',
               }
             },
    module: {
              loaders: [
              { test: /\.coffee$/, loader: "coffee-loader" },
              { test: /\.(coffee\.md|litcoffee)$/, loader: "coffee-loader?literate" },
              // TODO :( codemirror is going to modify window. add
              // 'imports?window=>{}' 
              { test: /codemirror.js$/, loaders: ['exports?window.CodeMirror']},
              {test: /codemirror-3.21/, exclude: /codemirror.js/, loader: 'imports?CodeMirror=cm/codemirror'},
              {test: /stacktrace/, loader: 'exports?printStackTrace'}
              ],
              // TODO coffeescript has a weird require browser
              noParse: /coffee-script.js/
            },
    // only include the moment english language
    plugins: [new webpack.ContextReplacementPlugin(/moment[\\\/]lang$/, /^\.\/(en)$/)]
}
