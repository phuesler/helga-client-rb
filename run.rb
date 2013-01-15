require "rubygems"
require "bundler/setup"
require 'faye/websocket'

EM.run {

  ws = Faye::WebSocket::Client.new('ws://localhost:8080')

  ws.onopen = lambda do |event|
    p [:open]
    ws.send('Hello, world!')
  end

  ws.onmessage = lambda do |event|
    p [:message, event.data]
  end

  ws.onclose = lambda do |event|
    p [:close, event.code, event.reason]
    ws = nil
  end


}
