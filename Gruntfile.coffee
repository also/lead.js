module.exports = (grunt) ->
  
  # Project configuration.
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
            src: ['node.*', 'modules.*', 'dsl.*', 'settings.*', 'opentsdb.*', 'graphite.*', 'functions.*', 'context.*', 'http.*']
            dest: 'dist/nodejs/'
          },
          {expand: true, cwd: 'lib', src: 'graphite_docs.js', dest: 'dist/nodejs/'}
        ]
    coffee:
      source:
        options:
          sourceMap: true
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
          cwd: 'spec'
          src: ['*.spec.coffee']
          dest: 'build/spec'
          ext: '.spec.js'
        ]
    requirejs:
      app:
        options:
          name: 'app'
          include: ['builtins', 'graphite', 'graph', 'opentsdb', 'github', 'input']
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

  grunt.registerTask "default", ['sass', 'concat:css', 'coffee', 'requirejs-optimize-config', 'requirejs']

  grunt.registerTask 'requirejs-optimize-config', 'Builds the mainConfigFile for r.js', ->
    config_script = grunt.file.read('build/requirejs_config.js')
    config = {}
    new Function(config_script).call(config)
    grunt.file.write 'build/requirejs_optimize_config.js', "requirejs(\n#{JSON.stringify config.require, undefined, 2});"
