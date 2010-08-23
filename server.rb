# Contains the DCGame::ClientConnection class.
require 'rubygems'
require 'eventmachine'

require 'message'
require 'player'
require 'client_connection'
require 'game'

require 'logger'
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
  g = Server::Game.new "Game"
  EventMachine::run do 
    EventMachine::start_server "127.0.0.1", 8801, ClientConnection, g do |client|
      $LOGGER.info "Added a new client"
      server.add_client client
      client.send_object Message::Handshake.new
    end
    puts "Hosted server on 127.0.0.1:8801"
  end

  # A serverside connection to a client.
  class ClientConnection < EventMachine::Connection
    include EM::P::ObjectProtocol

    # The game that this player is a member of. Sort of a moot point now,
    # because there is only one game.
    attr_accessor :game
    # The player associated with this connection.
    attr_accessor :player

    # setup
    def initialize g
      @game = g
    end

    # On create, make a player for this connection.
    def post_init
      $LOGGER.debug "New connection created."
      @player = Player.new("unnamed",self)
    end

    # receives a DCGame::Message and executes it using this as the target
    # connection.
    def receive_object message
      message.exec self 
    end

    # On death, as long as we are associated with a game, remove this player
    # from that game.
    def unbind
      unless @game.nil?
        @game.remove_player @player
      end
    end
  end
end

