require 'rubygems'
require 'eventmachine'

require 'game'
require 'interface'

module DCGame
  class ServerConnection < EventMachine::Connection
    include EM::P::ObjectProtocol
    attr_accessor :name, :game, :game_list

    def initialize name
      @name = name
      @game = nil
    end
    def post_init

    end
    def receive_object data
      data.exec self
    end
    def unbind
      $LOGGER.fatal "Disconnected from server. Aborting."
      EventMachine::stop_event_loop
    end
  
    def fail
      $LOGGER.info "Failed to join game, serverside. Aborting."
      EventMachine::stop_event_loop
    end

    def set_game game_name, players, settings
      $LOGGER.info "Setting the game."
      @game = Client::Game.new game_name, @name, players, settings
      $LOGGER.info "Done setting the game."
    end
  end
end

