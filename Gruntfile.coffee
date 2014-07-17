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
        files: [expand: true, cwd: 'app', src: 'graphite_*.js', dest: 'build/app']
      html:
        files: [{src: 'index-build.html', dest: 'build/web/index.html'}]
    coffee:
      source:
        files: [
          expand: true
          flatten: true
          cwd: 'app'
          src: ['**/*.coffee']
          dest: 'build/app/'
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
          dest: 'build/test'
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

  grunt.registerTask 'peg-grammars', 'Builds pegjs parsers', ->
    PEG = require 'pegjs'
    grammar = grunt.file.read 'app/graphite_grammar.peg'
    parser = PEG.buildParser grammar
    grunt.file.write 'app/graphite_parser.js', "module.exports = #{parser.toSource()};"
