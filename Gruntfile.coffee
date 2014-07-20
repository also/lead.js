_ = require 'underscore'

module.exports = (grunt) ->
  grunt.initConfig
    pkg: grunt.file.readJSON("package.json")
    webpack:
      web: require './webpack.config'
    sass:
      dist:
        files:
          'build/style.css': 'style.sass'
    concat:
      css:
        src: ['lib/reset.css', 'build/style.css', 'node_modules/codemirror/lib/codemirror.css', 'node_modules/codemirror/addon/hint/show-hint.css']
        dest: 'build/web/style.css'
    copy:
      javascript:
        files: [
          {expand: true, cwd: 'app', src: 'graphite_*.js', dest: 'build/node/app'},
          {expand: true, cwd: 'lib', src: 'colorbrewer.js', dest: 'build/node/app/lib'}
        ]
      html:
        files: [
          {src: 'index.html', dest: 'build/web/index.html'},
          {src: 'config.js', dest: 'build/web/config.js'}
        ]
      'dist-node':
        files: [
          {expand: true, cwd: 'build/node/app/', src: '**', dest: 'dist/node'},
          {expand: true, src: ['package.json', 'README.md', 'LICENSE.txt', 'docs/**', 'examples/**'], dest:'dist/node'}
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
    connect:
      server: {}

  grunt.loadNpmTasks 'grunt-sass'
  grunt.loadNpmTasks 'grunt-contrib-concat'
  grunt.loadNpmTasks 'grunt-contrib-copy'
  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-connect'
  grunt.loadNpmTasks 'grunt-webpack'
  grunt.loadTasks 'tasks'

  grunt.registerTask 'css', ['sass', 'concat:css']

  grunt.registerTask 'node', ['coffee', 'copy:javascript']
  grunt.registerTask 'web', ['css', 'webpack:web', 'copy:html']
  grunt.registerTask 'default', ['web', 'node']

  grunt.registerTask 'peg-grammars', 'Builds pegjs parsers', ->
    PEG = require 'pegjs'
    grammar = grunt.file.read 'app/graphite_grammar.peg'
    parser = PEG.buildParser grammar
    grunt.file.write 'app/graphite_parser.js', "module.exports = #{parser.toSource()};"

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
