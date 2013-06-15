net = require 'net'
WebSocketServer = require('ws').Server

ws_server = new WebSocketServer port: 8080
browser = null

ws_server.on 'connection', (ws) ->
  browser?.close()
  browser = ws

  ws.on 'close', ->
    browser = null

send = (program) ->
  browser?.send program


server = net.createServer (c) ->
  c.setEncoding 'utf8'
  c.on 'data', (data) ->
    send data

server.listen 8124
