#!/usr/local/bin/rsdl-ruby
# A client instance of the Dungeon Clash game. This will attempt to spawn a 
# connection to a local server, and play the game.
#
# Usage:
# rsdl client.rb <PLAYER_NAME>

require 'eventmachine'
require 'rubygame'
require 'logger'
include Rubygame

require './message'
require './client_game'
require './interface'

$MYNAME = ARGV[0]
#$LOGGER = Logger.new("logs/client_#{Time.now}_#{$MYNAME}", 'weekly')
$LOGGER = Logger.new STDOUT
$LOGGER.level = Logger::DEBUG

module DCGame
  class ServerConnection < EventMachine::Connection
    include EM::P::ObjectProtocol
    attr_accessor :name, :game, :game_list

    # Methods for the EM Connection
    def initialize name
      @name = name
      @game = nil
    end
    def post_init; end

    def receive_object data
      data.exec self
    end
    def unbind
      $LOGGER.fatal "Disconnected from server. Aborting."
      EventMachine::stop_event_loop
    end
  
    #the server will send an object which will do this
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
  EventMachine::run do
    $LOGGER.info "Attempting to connect to server."
    EventMachine::connect "127.0.0.1", 8801, ServerConnection, $MYNAME do |c|
      $LOGGER.info "Connected."

      #initialize
      queue = EventQueue.new
      queue.enable_new_style_events

      graphics = Interface.new c
      controller = graphics

      recent_times = [] 
      #limit framerate
      EventMachine::PeriodicTimer.new 1.0/300.0 do 
        #process events
        queue.each do |e|
          EventMachine::stop_event_loop if e.is_a? Events::QuitRequested
            controller.process_event e
        end

        # if we are in a game, draw it.
        graphics.draw if c.game
      end
    end
  end
ensure
  Rubygame.quit
end
