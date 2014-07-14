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
               }
             },
    module: {
              loaders: [
              { test: /\.coffee$/, loader: "coffee-loader" },
              { test: /\.(coffee\.md|litcoffee)$/, loader: "coffee-loader?literate" },
              // TODO :( codemirror is going to modify window. add
              // 'imports?window=>{}' 
              {test: /runmode/, loader: 'imports?CodeMirror=codemirror'}
              ],
              // TODO coffeescript has a weird require browser
              noParse: /coffee-script.js/
            },
    // only include the moment english language
    plugins: [new webpack.ContextReplacementPlugin(/moment[\\\/]lang$/, /^\.\/(en)$/)]
}
