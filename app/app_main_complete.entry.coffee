document.title = 'lead.js'

require 'style!raw!../build/web/style.css'
app = require './app'
app.init_app document.body
