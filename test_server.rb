require "rubygems"
require "bundler/setup"
require "em-websocket"
require "json"

EventMachine.run do

  COMMANDS = {
  "subscribe" => lambda do |ws, user_id, params|
    channel = params["channel"]
    if SUBSCRIBERS.has_key? channel
      CONNECTIONS[user_id][:channels] << {
        :name => channel,
        :sid => SUBSCRIBERS[channel].subscribe{|msg| ws.send msg}
      }
      SUBSCRIBERS[channel].push JSON.generate({
        :command => "ack",
        :params => {:status => "OK"}
      })
    end
  end,

  "unsubscribe" => lambda do |ws, user_id, params|
    channel = params["channel"]
    subscription = CONNECTIONS[user_id][:channels].find do |c|
      c[:name] == channel
    end
    if subscription
      SUBSCRIBERS[:channel].unsubscribe subscription[:sid]
    end
  end
}

SUBSCRIBERS = {
  "backend" => EventMachine::Channel.new,
  "frontend" => EventMachine::Channel.new
}

CONNECTIONS = {}

  EventMachine::WebSocket.start(:host => "0.0.0.0", :port => 8080) do |ws|
    connectionIdentifier = rand(1000000).to_s;
    ws.onopen {
      puts "WebSocket connection open"
      CONNECTIONS[connectionIdentifier] = {:channels => []};
      response = {
        :command => :status,
        :params => {
          :channels => [:backend, :frontend]
        }
      }
      ws.send JSON.generate(response)
    }

    ws.onclose { puts "Connection closed" }
    ws.onmessage { |msg|
      puts "Received message: #{msg}"
      message = nil
      begin
        message = JSON.parse(msg)
        command = COMMANDS[message["command"]]
        break unless command
        puts connectionIdentifier.inspect
        puts message.inspect
        command.call(ws, connectionIdentifier, message["params"])
      rescue Exception => e
        puts e.inspect
        puts "Message could not be parsed as JSON"
      end
      ws.send(JSON.generate({
        :command => "ack",
        :params => {:status => "OK"}
      }))
    }
  end
end

