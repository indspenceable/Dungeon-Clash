require 'rubygems'
require 'eventmachine'

require 'message'
require 'player'
require 'client_connection'
require 'game'

require 'logger'

#$LOGGER = Logger.new("logs/sever_#{Time.now}",'weekly')
$LOGGER = Logger.new STDOUT
$LOGGER.level = Logger::DEBUG

module DCGame
  class ServerManager
    def initialize
      @local_clients = [] 
    end
    def add_client client
      @local_clients << client
    end
  end
  #run the server.
  server = ServerManager.new
  g = Game.new "Game"
  EventMachine::run do 
    EventMachine::start_server "127.0.0.1", 8801, ClientConnection, g do |client|
      puts "Added a new client"
      server.add_client client
      client.send_object Message::Handshake.new
    end
    puts "Hosted server on 127.0.0.1:8801"
  end
end
