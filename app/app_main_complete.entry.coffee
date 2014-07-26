document.title = 'lead.js'

$ = require 'jquery'
require 'style!raw!../build/web/style.css'
app = require './app'
$ app.init_app document.body
