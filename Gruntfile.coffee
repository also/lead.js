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
        options:
          bundleExec: true
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
    requirejs:
      app:
        options:
          name: 'app'
          include: ['builtins', 'graphite', 'graph', 'opentsdb', 'github', 'input', 'compat']
          excludeShallow: ['config']
          out: 'dist/lead-app.js'
          mainConfigFile: 'build/requirejs_optimize_config.js'
          baseUrl: 'build'
          paths:
            punycode: 'empty:'
            IPv6: 'empty:'
            SecondLevelDomains: 'empty:'
          optimize: 'none'

  grunt.loadNpmTasks 'grunt-contrib-sass'
  grunt.loadNpmTasks 'grunt-contrib-concat'
  grunt.loadNpmTasks 'grunt-contrib-copy'
  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-requirejs'
  grunt.loadNpmTasks 'grunt-contrib-connect'
  grunt.loadTasks 'tasks'

  grunt.registerTask 'css', ['sass', 'concat:css']

  grunt.registerTask "default", ['css', 'coffee', 'peg-grammars', 'copy:parser', 'requirejs-optimize-config', 'requirejs', 'copy:dist']

  grunt.registerTask 'requirejs-optimize-config', 'Builds the mainConfigFile for r.js', ->
    config_script = grunt.file.read('build/requirejs_config.js')
    config = {}
    new Function(config_script).call(config)
    grunt.file.write 'build/requirejs_optimize_config.js', "requirejs(\n#{JSON.stringify config.require, undefined, 2});"

  grunt.registerTask 'peg-grammars', 'Builds pegjs parsers', ->
    PEG = require 'pegjs'
    grammar = grunt.file.read 'src/graphite_grammar.peg'
    parser = PEG.buildParser grammar
    grunt.file.write 'src/graphite_parser.js', "define(function() {return #{parser.toSource()};});"
