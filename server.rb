# Contains the DCGame::ClientConnection class.
require 'eventmachine'

require './message'
require './player'
require './game'

require 'logger'
$LOGGER = Logger.new STDOUT
$LOGGER.level = Logger::DEBUG

module DCGame
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
      @g = g
    end

    def try_join_game name
      @game = nil
      return $LOGGER.warn "Trying to join a full game. Rejecting." if @g.full?
      return $LOGGER.warn "Duplicate name, rejecting." if @g.players.any?{ |p| p.name == name}
      return $LOGGER.warn "Trying to join with no name." if "#{name}"==""
      @game = @g
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
  #run the server.
  g = Server::Game.new "Game"
  EventMachine::run do 
    EventMachine::start_server "127.0.0.1", 8801, ClientConnection, g do |client|
      $LOGGER.info "Added a new client"
      client.send_object Message::Handshake.new
    end
    puts "Hosted server on 127.0.0.1:8801"
  end

end

