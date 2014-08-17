document.title = 'lead.js'

require "!style!css!sass!./style.scss"
app = require './app'
app.init_app document.body
