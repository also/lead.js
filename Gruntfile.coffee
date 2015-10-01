_ = require 'underscore'
require('babel/register')

webpack_config = require './webpack.config'
webpack_style_config = _.extend {}, webpack_config,
  entry: '!css!sass!./app/style.scss'
  output:
    path: __dirname + '/build/web'
    filename: 'style.js'
    library: 'lead_style'
    libraryTarget: 'commonjs2'

module.exports = (grunt) ->
  grunt.initConfig
    pkg: grunt.file.readJSON("package.json")
    webpack:
      web: webpack_config
      css: webpack_style_config
    copy:
      javascript:
        files: [
          {expand: true, cwd: 'app', src: 'graphite_*.js', dest: 'build/node/app'},
          {expand: true, cwd: 'lib', src: 'colorbrewer.js', dest: 'build/node/app/lib'}
        ]
      static:
        files: [
          {src: 'index.html', dest: 'build/web/index.html'},
          {src: 'config.js', dest: 'build/web/config.js'}
        ]
      'dist-node':
        files: [
          {expand: true, cwd: 'build/node/app/', src: '**', dest: 'dist/node'},
          {expand: true, src: ['package.json', 'README.md', 'LICENSE.txt', 'docs/**', 'examples/**'], dest:'dist/node'}
        ]
      'dist-web':
        files: [
          {expand: true, cwd: 'build/web', src: ['config.js', 'lead-app.js', 'style.css', 'index.html'], dest: 'dist/web'},
          {expand: true, src: ['README.md', 'LICENSE.txt', 'docs/**', 'examples/*'], dest: 'dist/web'}
        ]
    compress:
      web:
        options:
          archive: 'dist/lead.js.zip'
        files: [
          {expand: true, cwd: 'dist/web', src: ['**'], dest: 'lead.js/'}
        ]
    coffee:
      source:
        files: [
          expand: true
          flatten: true
          cwd: 'app'
          src: ['**/*.coffee']
          dest: 'build/node/app'
          ext: '.js'
          extDot: 'last'
        ]
      tests:
        options:
          sourceMap: true
        files: [
          expand: true
          flatten: true
          cwd: 'test'
          src: ['*.coffee']
          dest: 'build/node/test'
          ext: '.js'
          extDot: 'last' # FFS grunt, why would you rename foo.test.coffee to foo.js :(
        ]
    babel:
      options:
        blacklist: ['strict']
        optional: ['runtime', 'es7.objectRestSpread']
      source:
        files: [{
          expand: true
          cwd: 'app'
          src: ['**/*.js']
          dest: 'build/node/app'
          ext: '.js'
          extDot: 'last'
        }, {
          expand: true
          cwd: 'app/node'
          src: ['*.js']
          dest: 'build/node/app'
        }]
      tests:
        options:
          blacklist: ['strict']
          optional: ['runtime', 'es7.objectRestSpread']
        files: [
          expand: true
          cwd: 'test'
          src: ['**/*.js']
          dest: 'build/node/test'
        ]
    connect:
      server: {}

  grunt.loadNpmTasks 'grunt-contrib-copy'
  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-connect'
  grunt.loadNpmTasks 'grunt-webpack'
  grunt.loadNpmTasks 'grunt-contrib-compress'
  grunt.loadNpmTasks 'grunt-babel'
  grunt.loadTasks 'tasks'

  grunt.registerTask 'node', ['coffee', 'babel', 'copy:javascript']
  grunt.registerTask 'web', ['webpack', 'css', 'copy:static']
  grunt.registerTask 'default', ['web', 'node']
  grunt.registerTask 'dist', ['copy:dist-node', 'copy:dist-web']

  grunt.registerTask 'css', ->
    grunt.file.write 'build/web/style.css', require './build/web/style.js'

  grunt.registerTask 'npm-link', ->
    done = @async()
    spawned = grunt.util.spawn cmd: "npm", args: ['link'], opts: {cwd: "#{__dirname}/dist/node", env: _.extend({npm_config_prefix: "#{__dirname}/build/node/npm"}, process.env)}, (err, result, code) ->
      if err?
        grunt.log.error 'npm link failed'
        done false
      else
        done()
    spawned.stdout.pipe(process.stdout)
    spawned.stderr.pipe(process.stderr)

  grunt.registerTask 'run-node', ->
    script = grunt.option 'script'
    unless script?
      grunt.fail.warn 'script option is required.'

    if /\.coffee$/.test script
      cmd = 'node_modules/coffee-script/bin/coffee'
    else
      cmd = 'node'
    done = @async()
    spawned = grunt.util.spawn cmd: cmd, args: [script], opts: {env: _.extend({NODE_PATH: "#{__dirname}/build/node/npm/lib/node_modules"}, process.env)}, (err, result, code) ->
      if err?
        grunt.log.error 'script failed'
        done false
      else
        done()
    spawned.stdout.pipe(process.stdout)
    spawned.stderr.pipe(process.stderr)
