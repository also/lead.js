webpack = require('webpack');

module.exports = {
  debug: true,
  context: __dirname,
  entry: {
    app: './app/app_main.entry',
    'app-complete': './app/app_main_complete.entry',
    test: './test/run_mocha_browser'
  },
  output: {
    path: __dirname + "/build/web",
    filename: "lead-[name].js"
  },
  externals: {
    'jsdom': true
  },
  resolve: {
    extensions: ['', '.webpack.js', '.web.js', '.js', '.web.coffee', '.coffee'],
    alias: {
      // i think this is necessary becase bacon.model references 'baconjs' in commonjs and 'bacon' in amd
      'bacon': 'baconjs',
      'coffee-script': __dirname + '/lib/coffee-script',
    }
  },
  module: {
    loaders: [
      {test: /\.coffee$/, loader: "coffee-loader"},
      {test: /coffee-script.js$/, loader: 'exports?exports.CoffeeScript'},
      {test: /colorbrewer/, loader: 'exports?colorbrewer'}
    ],
    // TODO coffeescript has a weird require browser
    noParse: /coffee-script.js/
  },
  plugins: [
    // only include the moment english language
    new webpack.ContextReplacementPlugin(/moment[\\\/]lang$/, /^\.\/(en)$/),
    // only js and coffe files allowed in the ./app context
    new webpack.ContextReplacementPlugin(/\/app$/, /^\.\/[^.]*$/),
    new webpack.NormalModuleReplacementPlugin(/^\.\/lib\/colorbrewer$/, '../lib/colorbrewer')
  ]
}
