require "rubygems"
require "bundler/setup"
require "em-websocket"
require "json"

COMMANDS = {
  "subscribe" => lambda do |ws, user, params|
    channel = params["channel"]
    if SUBSCRIBERS.has_key? channel
      user[:channels] << {
        :name => channel,
        :sid => SUBSCRIBERS[channel].subscribe{|msg| ws.send msg}
      }
      SUBSCRIBERS[channel].push JSON.generate({
        :command => "info",
        :params => {:message => "client #{user[:nick]} subscribed to #{channel}"}
      })
    end
  end,

  "unsubscribe" => lambda do |ws, user, params|
    channel = params["channel"]
    subscription = user[:channels].find do |c|
      c[:name] == channel
    end
    if subscription
      SUBSCRIBERS[subscription[:name]].unsubscribe subscription[:sid]
      SUBSCRIBERS[channel].push JSON.generate({
        :command => "info",
        :params => {:message => "client #{user[:nick]} unsubscribed from #{channel}"}
      })
    end
  end,

  "registerNick" => lambda do |ws, user, params|
    user[:nick] = params[:name]
  end

}

SUBSCRIBERS = {
  "backend" => EventMachine::Channel.new,
  "frontend" => EventMachine::Channel.new,
  "all" => EventMachine::Channel.new
}

CONNECTIONS = {}


EventMachine.run do


  EventMachine::WebSocket.start(:host => "0.0.0.0", :port => 8080) do |ws|
    connectionIdentifier = rand(1000000).to_s;
    ws.onopen {
      puts "WebSocket connection open"
      CONNECTIONS[connectionIdentifier] = {
        :nick => connectionIdentifier,
        :channels => [
          {
            :name => "all",
            :sid => SUBSCRIBERS["all"].subscribe{|msg| ws.send msg}
          }
        ]};
        response = {
          :command => :status,
          :params => {
            :channels => [:backend, :frontend]
          }
        }
        ws.send JSON.generate(response)
    }

    ws.onclose {
      CONNECTIONS[connectionIdentifier][:channels].each do |subscription|
        SUBSCRIBERS[subscription[:name]].unsubscribe subscription[:sid]
      end
      CONNECTIONS.delete connectionIdentifier
      SUBSCRIBERS["all"].push JSON.generate({
        :command => "info",
        :params => {:message => "client #{connectionIdentifier} left"}
      })

      puts "Connection closed"
    }
    ws.onmessage { |msg|
      puts "Received message: #{msg}"
      message = nil
      begin
        message = JSON.parse(msg)
        command = COMMANDS[message["command"]]
        break unless command
        command.call(ws, CONNECTIONS[connectionIdentifier], message["params"])
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

