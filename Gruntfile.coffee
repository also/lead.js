NODE_MODULES = [
  'node'
  'modules'
  'dsl'
  'settings'
  'opentsdb'
  'graphite'
  'functions'
  'context'
  'http'
  'graphite_parser'
  'builtins'
  'notebook'
  'editor'
  'compat'
  'graph'
  'colors'
]

module.exports = (grunt) ->
  grunt.initConfig
    pkg: grunt.file.readJSON("package.json")
    sass:
      dist:
        files:
          'build/style.css': 'style.sass'
    concat:
      css:
        src: ['lib/reset.css', 'build/style.css', 'lib/codemirror-3.21/codemirror.css', 'lib/codemirror-3.21/show-hint.css']
        dest: 'dist/style.css'
    copy:
      nodejs:
        files: [
          {
            expand: true
            cwd: 'build'
            src: NODE_MODULES.map (m) -> "#{m}.*"
            dest: 'dist/nodejs/'
          },
          {expand: true, cwd: 'lib', src: ['graphite_docs.js', 'colorbrewer.js'], dest: 'dist/nodejs/'}
        ]
      parser:
        files: [src: 'src/graphite_parser.js', dest: 'build/graphite_parser.js']
      dist:
        files: [
          {src: 'build/config.js', dest: 'dist/config.js'}
          {src: 'lib/require.js', dest: 'dist/require.js'},
          {src: 'index-build.html', dest: 'dist/index.html'}
        ]
    coffee:
      source:
        files: [
          expand: true
          flatten: true
          cwd: 'src'
          src: ['*.coffee']
          dest: 'build/'
          ext: '.js'
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
        ]
    connect:
      server: {}

  grunt.loadNpmTasks 'grunt-sass'
  grunt.loadNpmTasks 'grunt-contrib-concat'
  grunt.loadNpmTasks 'grunt-contrib-copy'
  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-connect'
  grunt.loadTasks 'tasks'

  grunt.registerTask 'css', ['sass', 'concat:css']

  grunt.registerTask "default", ['css', 'coffee', 'peg-grammars', 'copy:parser', 'copy:dist']

  grunt.registerTask 'peg-grammars', 'Builds pegjs parsers', ->
    PEG = require 'pegjs'
    grammar = grunt.file.read 'src/graphite_grammar.peg'
    parser = PEG.buildParser grammar
    grunt.file.write 'src/graphite_parser.js', "define(function() {return #{parser.toSource()};});"
