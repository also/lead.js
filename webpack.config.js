module.exports = {
  debug: true,
    context: __dirname + "/src",
    entry: "./app",
    output: {
        path: __dirname + "/dist",
        filename: "bundle.js"
    },
    resolve: {
               root: [__dirname + '/src', __dirname + '/lib'],
               //modulesDirectories: [],
               extensions: ['.webpack.js', '.web.js', '.js', '.coffee'],
               alias: {d3: 'd3.v3',
                 baconjs: 'Bacon',
                 URIjs: 'URI',
                 react: 'react-0.10.0',
                 'cm/codemirror': 'codemirror-3.21/codemirror',
                 'cm/runmode': 'codemirror-3.21/runmode',
                 'cm/coffeescript': 'codemirror-3.21/coffeescript',
                 'cm/show-hint': 'codemirror-3.21/coffeescript',
                 'stacktrace-js': 'stacktrace-min-0.4'
               }
             },
    module: {
              loaders: [
              { test: /\.coffee$/, loader: "coffee-loader" },
              { test: /\.(coffee\.md|litcoffee)$/, loader: "coffee-loader?literate" }
              ]
            }
}
