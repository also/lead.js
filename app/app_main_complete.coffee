document.title = 'lead.js'
document.write '<h1>lead.js</h1><div id=document class=cm-s-idle></div>'

$ = require 'jquery'
require '!style!css!../build/web/style.css'
app = require './app'
$ app.init_app
