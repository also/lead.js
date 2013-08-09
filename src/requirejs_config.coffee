@require =
  deps: ['bootstrap']
  paths:
    lib: '../lib'
    spec: '../spec'
    cm: '../lib/codemirror-3.12'
    underscore: '../lib/underscore'
    jquery: '../lib/jquery'
    d3: '../lib/d3.v3'
    URIjs: '../lib/URI'
    'stacktrace-js': '../lib/stacktrace-min-0.4'
    domReady: '../lib/domReady'
    q: '../lib/q'
    moment: '../lib/moment'
    marked: '../lib/marked'
    'coffee-script': '../lib/coffee-script'
    colorbrewer: '../lib/colorbrewer'
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
    'd3':
      exports: 'd3'
    'colorbrewer':
      exports: 'colorbrewer'
    'underscore':
      exports: '_'
    'stacktrace-js':
      exports: 'printStackTrace'
