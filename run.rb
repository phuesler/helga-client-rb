require "rubygems"
require "bundler/setup"
require "faye/websocket"
require "json"

COMMANDS = {
  "status" => lambda{|params| puts params.inspect},
  "message" => lambda{|params| puts params.inspect},
  "ack" => lambda{|params| puts "received ack"},
  "error" => lambda{|params| puts "an error happended"}
}

EM.run {

  ws = Faye::WebSocket::Client.new('ws://localhost:8080')

  ws.onopen = lambda do |event|
    p [:open]
    init_hash = {
        :token => "developer token",
        :command => :subscribe,
        :params => {:channel => "backend"}
    }
    ws.send(JSON.generate(init_hash))
  end

  ws.onmessage = lambda do |event|
    message = nil
    begin
      message = JSON.parse(event.data)
      puts message
      command = COMMANDS[message["command"]]
      break unless command
      command.call(message["params"])
    rescue Exception => e
      puts e.inspect
      puts "message could not be parsed: #{event.data}"
    end
  end

  ws.onclose = lambda do |event|
    p [:close, event.code, event.reason]
    ws = nil
  end


}
