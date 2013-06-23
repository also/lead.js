requirejs.config
  paths:
    lib: '../lib'
    cm: '../lib/codemirror-3.12'
  shim:
    'cm/codemirror':
        exports: 'CodeMirror'
    'cm/javascript': ['cm/codemirror']
    'cm/coffeescript': ['cm/codemirror']
    'cm/runmode': ['cm/codemirror']
    'cm/show-hint': ['cm/codemirror']

# exclude optional URI modules
define("lib/#{m}", -> null) for m in ['IPv6', 'punycode', 'SecondLevelDomains']

requirejs ['notebook'], (notebook) ->
  $ notebook.init_editor
