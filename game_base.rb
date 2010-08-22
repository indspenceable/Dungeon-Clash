require 'game_map'

module DCGame
  module Games

    class PlayerFinalizationTracker
      def initialize
        clear_players
      end
      def clear_players
        @finalization_states = Hash.new
      end
      def set_player_finalized player_name, state
       @finalization_states[player_name] = state 
      end
      def player_finalized? player_name
        return false unless @finalization_states.key? player_name
        @finalization_states[player_name]
      end
      def all_players_finalized?
        @finalization_states.values.include? false
      end
    end

    # The base class for server and client games.
    # relies on game_map.
    class Base
      # The list of players for this game. Array of strings
      attr_accessor :players
      # The name of this game. String.
      attr_accessor :name
      # The GameMap for this game.
      attr_accessor :map

      # The current action mode of the game
      # Options: lobby, character_selection, game_play
      attr_reader :mode


      # Games should all have these variables set.
      def initailize name, map
        #set meta data
        @name = name
        @players = Array.new
        @map = map
        # mode defaults to lobby
        @mode = :lobby
          
        #data that gets set when game goes back to lobby
        @characters = Array.new
        @current_chracter = nil

        @finalized_players = PlayerFinalizationTracker.new
      end

      # is the game full? if so, its probably going to jump to Game.begin_character_selection
      def full?
        players.length == @map.player_capacity
      end
      
      def add_player player
        @players << player
        $LOGGER.info "Player has joined."
      end

      #   :add_player
      #   :return_to_lobby
      #

      #   :finalize_player
      #refactor out?
      #   :all_players_finalized

    end
  end 
  module Server
    class Game < Games::Base

      def initialize name
        super name, GameMap.new(25,25)
      end

      # Inform the game that a player has joined.
      #TODO Make this work with a string, using PlayerIndex
      def add_player player
        super
        if full?
          begin_character_selection
        else 
          $LOGGER.info "Informing those connected that #{player} has joined."
          players.reject{|p| p==player}.each do |p|
            p.owner.send_object Message::Message.new(:add_player, connection.player.name)
          end
        end
      end

      # All the players have joined, so we've started character selection.
      # TODO make this work with a string, using PlayerIndex
      def begin_character_selection
        $LOGGER.info "All players have joined, so game is moving into character selection."
        @mode = :select_characters
        players.each do |p|
          @finalized_players.set_player_finalized p.name, false
          #p.owner.send_object Message::SelectCharacters.new players.reject{ |pl| p==pl}.collect{ |pl| pl.name}
          p.owner.send Message::Game.new(:select_charactesr, players.reject{ |pl| p==pl}.collect{ |pl| pl.name}
        end
      end

      # Tell the game that this player is finished choosing their character.
      def set_player_finalized player
        $LOGGER.debug "We are calling finalize_player on the server side."
        @finalized_players[player] = true

        5.times do
          loc = [rand(10), rand(10)]
          loc = [rand(10), rand(10)] while @characters.any?{|c| c.location == loc} || @settings.map.tile_at(*loc)!= :empty

          @characters << (Character.new player.name, "soldier", [], loc)
          puts "Created a character at #{loc}."
        end

        $LOGGER.info "Are all players finalized? #{@finalized_players.values}"
        return all_players_finalized unless @finalized_players.values.include? false 

        players.each do |p|
          puts "Sending a 'finalized player message'"
          p.owner.send_object Message::PlayerFinalized.new player.name
        end
      end

      # When all players are finalized, this method gets called.
      def all_players_finalized
        $LOGGER.info "All Players are finalized, so the game is starting."
        @current_character = @characters[rand @characters.length].c_id
        msg = Message::StartGame.new @characters, @current_character
        players.each do |p|
          p.owner.send_object msg
        end
      end

      # For whatever reason, this game must return to lobby and restart.
      def return_to_lobby 
        $LOGGER.debug "Game is returning to lobby."
        @mode = :lobby
        @finalized_players = nil
        reset_variables
      end

      # Player has left the game.
      def remove_player p
        puts "We are removing <#{p.name}>"
        players.delete p
        players.each do |player|
          player.owner.send_object Message::PlayerLeft.new p.name
        end
        return_to_lobby if started?
      end

      # If the game has started
      def started?
        @mode!=:lobby
      end


      # is a location occupied?
      def occupied? x,y
        map.tile_at(x,y) != :empty 
      end

      def move_current_character_on_path path
        moved_path
        prev = 
          path.each do |l|
          if occupied? *l

          else
            prev = l
          end
          end
      end
    end
  end
end
