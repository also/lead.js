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
        src: ['lib/reset.css', 'build/style.css', 'lib/codemirror-3.12/codemirror.css']
        dest: 'dist/style.css'
    copy:
      nodejs:
        files: [
          {
            expand: true
            cwd: 'build'
            src: ['node.*', 'modules.*', 'dsl.*', 'settings.*', 'opentsdb.*', 'graphite.*', 'functions.*', 'context.*', 'http.*', 'graphite_parser.*']
            dest: 'dist/nodejs/'
          },
          {expand: true, cwd: 'lib', src: 'graphite_docs.js', dest: 'dist/nodejs/'}
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
  grunt.loadTasks 'tasks'

  grunt.registerTask "default", ['sass', 'concat:css', 'coffee', 'peg-grammars', 'copy:parser', 'requirejs-optimize-config', 'requirejs', 'copy:dist']

  grunt.registerTask 'requirejs-optimize-config', 'Builds the mainConfigFile for r.js', ->
    config_script = grunt.file.read('build/requirejs_config.js')
    config = {}
    new Function(config_script).call(config)
    grunt.file.write 'build/requirejs_optimize_config.js', "requirejs(\n#{JSON.stringify config.require, undefined, 2});"

  grunt.registerTask 'tests', 'Runs the Mocha tests using PhantomJS', ->
    done = this.async()
    grunt.util.spawn cmd: 'phantomjs', args: ['build/test/phantom.js'], (err, result, code) ->
      if err?
        grunt.log.error 'Tests failed'
        grunt.log.error result.stdout
        done false
      else
        grunt.log.ok 'Tests passed'
        done()

  grunt.registerTask 'peg-grammars', 'Builds pegjs parsers', ->
    PEG = require 'pegjs'
    grammar = grunt.file.read 'src/graphite_grammar.peg'
    parser = PEG.buildParser grammar
    grunt.file.write 'src/graphite_parser.js', "define(function() {return #{parser.toSource()};});"
