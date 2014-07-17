webpack = require('webpack');

module.exports = {
  debug: true,
    context: __dirname,
    entry: {app: 'app/app_main',
     test: 'test/run_mocha_browser'
     },
    output: {
        path: __dirname + "/build",
        filename: "lead-[name].js"
    },
    externals: {
                 'jsdom': true
               },
    resolve: {
               root: [__dirname + '/app', __dirname],
               //modulesDirectories: [],
               extensions: ['', '.webpack.js', '.web.js', '.js', '.coffee'],
               alias: {
                 // i think this is necessary becase bacon.model references 'baconjs' in commonjs and 'bacon' in amd
                 'bacon': 'baconjs',
                 'coffee-script': 'lib/coffee-script'
               }
             },
    module: {
              loaders: [
              { test: /\.coffee$/, loader: "coffee-loader" },
              { test: /\.(coffee\.md|litcoffee)$/, loader: "coffee-loader?literate" },
              // TODO :( codemirror is going to modify window. add
              // 'imports?window=>{}' 
              {test: /runmode/, loader: 'imports?CodeMirror=codemirror'},
              {test: /colorbrewer/, loader: 'exports?colorbrewer'}
              ],
              // TODO coffeescript has a weird require browser
              noParse: /coffee-script.js/
            },
    // only include the moment english language
    plugins: [new webpack.ContextReplacementPlugin(/moment[\\\/]lang$/, /^\.\/(en)$/)]
}
