module.exports = (grunt) ->
  
  # Project configuration.
  grunt.initConfig
    pkg: grunt.file.readJSON("package.json")
    coffee:
      all:
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
    requirejs:
      optimize:
        options:
          name: 'main'
          mainConfigFile: 'build/requirejs_optimize_config.js'
          baseUrl: 'build'
          out: 'lead.js'
          paths:
            punycode: 'empty:'
            IPv6: 'empty:'
            SecondLevelDomains: 'empty:'
          optimize: 'none'

  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-requirejs'

  grunt.registerTask "default", ["coffee", 'requirejs-optimize-config', 'requirejs']

  grunt.registerTask 'requirejs-optimize-config', 'Builds the mainConfigFile for r.js', ->
    config_script = grunt.file.read('build/requirejs_config.js')
    config = {}
    new Function(config_script).call(config)
    grunt.file.write 'build/requirejs_optimize_config.js', "requirejs(\n#{JSON.stringify config.require, undefined, 2});"
