var webpack = require('webpack');

module.exports = {
  debug: true,
  context: __dirname,
  // the arrays are a weird workaround the "a dependency to an entry point is not allowed" error
  // https://github.com/webpack/webpack/issues/300#issuecomment-45313650
  entry: {
    app: ['./app/app'],
    'app-complete': './app/app_main_complete.entry',
    test: './test/run_mocha_browser'
  },
  output: {
    path: __dirname + "/build/web",
    filename: "lead-[name].js"
  },
  resolve: {
    extensions: ['', '.webpack.js', '.web.js', '.js', '.web.coffee', '.coffee'],
    alias: {
      // bacon.model references 'baconjs' in commonjs and 'bacon' in amd
      'bacon': 'baconjs',
      'coffee-script': __dirname + '/lib/coffee-script',
    }
  },
  module: {
    loaders: [
      {test: /\.coffee$/, loader: "coffee-loader"},

      // shims
      {test: /baconjs/, loader: 'imports?jQuery=jquery'},
      {test: /coffee-script.js$/, loader: 'exports?exports.CoffeeScript'}
    ],
    // TODO coffeescript has a weird require browser
    noParse: /coffee-script.js$/
  },
  plugins: [
    // only include the moment english language
    new webpack.ContextReplacementPlugin(/moment[\\\/]lang$/, /^\.\/(en)$/),

    // no "." and no subdirectories in ./app context. this excludes .entry.coffee files, and files that don't match extensions
    new webpack.ContextReplacementPlugin(/\/app$/, false, /^\.\/[^.]*$/),
    new webpack.NormalModuleReplacementPlugin(/^\.\/lib\/colorbrewer$/, '../lib/colorbrewer')
  ]
}
