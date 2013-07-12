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

  grunt.loadNpmTasks 'grunt-contrib-coffee'

  grunt.registerTask "default", ["coffee"]
