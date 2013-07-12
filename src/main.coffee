requirejs.config
  paths:
    lib: '../lib'
    spec: '../spec'
    cm: '../lib/codemirror-3.12'
    underscore: '../lib/underscore'
    jquery: '../lib/jquery'
  shim:
    'cm/codemirror':
        exports: 'CodeMirror'
    'cm/javascript': ['cm/codemirror']
    'cm/coffeescript': ['cm/codemirror']
    'cm/runmode': ['cm/codemirror']
    'cm/show-hint': ['cm/codemirror']
    'cm/markdown': ['cm/codemirror']
    'cm/gfm': ['cm/gfm']
    'jquery':
      exports: 'jQuery'
    'lib/d3.v3':
      exports: 'd3'
    'lib/colorbrewer':
      exports: 'colorbrewer'
    'underscore':
      exports: '_'

# exclude optional URI modules
define("lib/#{m}", -> null) for m in ['IPv6', 'punycode', 'SecondLevelDomains']

# TODO how is this supposed to work?
unless this.testing
  requirejs ['app'], (app) ->
    $ app.init_app
