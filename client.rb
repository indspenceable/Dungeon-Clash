#!/usr/local/bin/rsdl-ruby
# A client instance of the Dungeon Clash game. This will attempt to spawn a 
# connection to a local server, and play the game.
#
# Usage:
# rsdl client.rb <PLAYER_NAME>

require 'rubygems'
require 'eventmachine'
require 'server_connection'
require 'message'
require 'rubygame'
require 'logger'
include Rubygame

$MYNAME = ARGV[0]
#$LOGGER = Logger.new("logs/client_#{Time.now}_#{$MYNAME}", 'weekly')
$LOGGER = Logger.new STDOUT
$LOGGER.level = Logger::DEBUG

module DCGame
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
      EventMachine::PeriodicTimer.new 1.0/60.0 do 
        #recent_times << Time.now
        #if recent_times.size == 20
        #  avg = Array.new
        #  recent_times.each_cons(2) do |x|
        #    avg << (x[1]-x[0])
        #  end
        #  puts "average: #{avg.inject(0){|total,current| total += current} / recent_times.size}"
        #  recent_times = Array.new
        #end


        #process events
        queue.each do |e|
          EventMachine::stop_event_loop if e.is_a? Events::QuitRequested
          if e.is_a?(Events::KeyPressed) && c.game && c.game.mode == :select_characters
            $LOGGER.info "This player has chosen characters."
            c.send_object Message::ChooseCharacters.new []
          else
            controller.process_event e
          end
        end

        #draw
        if c.game
          graphics.draw c.game
        else
          graphics.draw c.game_list 
        end

      end
    end
  end
ensure
  Rubygame.quit
end
