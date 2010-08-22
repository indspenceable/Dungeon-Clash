require 'board'

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

    #Right now this just holds characters.
    # In fact you can just get the list, but if you want a shortcut (like, 
    # is there a character at this location?) then that is a possibility
    # as well.
    class State
      attr_accessor :characters
      def initialize setup
        @characters = setup
      end 
      def is_character_at? x,y
        @characters.any?{|c| c.location == [x,y]}
      end
      def character_at x,y
        @characters.find{|c| c.location == [x,y]}
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

      #Hey, interaces need to see what players are finalized
      attr_accessor :finalized_players

      # Games should all have these variables set.
      def initialize name, map
        #set meta data
        @name = name
        @players = Array.new
        @map = map

        # mode defaults to lobby
        @mode = :lobby
        @state = State.new []

        #This stores the c_id of the current_character
        @current_chracter = nil
        @finalized_players = PlayerFinalizationTracker.new
      end

      def reset_variables
        @current_character = nil
        @state = State.new
        @finalized_players.clear
      end

      # is the game full? if so, its probably going to jump to Game.begin_character_selection
      def full?
        players.length == @map.player_capacity
      end

      def add_player player
        @players << player
        $LOGGER.info "Player has joined."
      end

      def set_current_character new_c_id
        @current_character = new_c_id
      end
      def character_for_current_move
        @state.chars.each do |c|
          return c if c.c_id == @current_character
        end
        nil
      end

      def player_for_current_move
        character_for_current_move.owner
      end

    end
  end 
  module Server
    class Game < Games::Base

      def initialize name
        super(name, Board.new(25,25))
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
          p.owner.send Message::Game.new(:select_charactesr, players.reject{ |pl| p==pl}.collect{ |pl| pl.name})
        end
      end

      # Tell the game that this player is finished choosing their character.
      def set_player_finalized player
        @finalized_players.set_player_finalized player.name, true

        #generate random characters.
        5.times do
          loc = [rand(10), rand(10)]
          loc = [rand(10), rand(10)] while @state.characters.any?{|c| c.location == loc} || @map.tile_at(*loc)!= :empty
          @characters << (Character.new player.name, "soldier", [], loc)
          puts "Created a character at #{loc}."
        end

        if @finalized_players.all_players_finalized?
          $LOGGER.info "All Players are finalized, so the game is starting."
          @current_character = @characters[rand @characters.length].c_id
          players.each do |p|
            p.owner.send_object Message::StartGame.new @characters, @current_character
          end
        else
          $LOGGER.debug "Sending out finalized_player alert."
          players.each do |p|
            p.owner.send_object Message::PlayerFinalized.new player.name
          end
        end
      end

      # For whatever reason, this game must return to lobby and restart.
      def return_to_lobby 
        $LOGGER.debug "Game is returning to lobby."
        @mode = :lobby
        @finalized_players.clear_players
        reset_variables
      end

      # Player has left the game.
      def remove_player p
        $LOGGER.debug "Player: #{p.name} has left the game."
        players.delete p
        players.each do |player|
          player.owner.send_object Message::PlayerLeft.new p.name
        end
        return_to_lobby
      end

      # is a location occupied?
      def passable? x,y
        map.tile_at(x,y) != :empty 
      end

      #TODO unimplemented
      def move_current_character_on_path path
      end
    end
  end

  module Client
    class Game
      #REFACTORED
      def initialize name, pname, players, map
        super(name, map)
        $LOGGER.info "Constructing a game_interface."
        @shadows = ShadowMap.new @settings
      end

      # This makes the game being character selection mode. 
      # REFACTORED
      def begin_character_selection_mode player_list
        @players = player_list
        $LOGGER.debug "Game is moving into character selection phase. Other players are #{@players.inspect}"
        @mode = :select_characters
        @finalized_players.clear_players

        #this is the part where you choose players
        @players.each do |p|
          @finalized_players.set_player_finalized p, true
        end
      end

      #We've received word that we need to go back to the lobby.
      def return_to_lobby
        $LOGGER.info "The game is returning to lobby mode."
        #TODO do we want to call reset_variables?
        @mode = :lobby
      end

      # if a player gets finalized, forward that all
      def set_player_finalized pname
        $LOGGER.debug "Player is finalized: #{pname}."
        @finalized_players.set_player_finalized pname, true
      end

      # A* Pathfinding
      def calculate_path_between start, dest
        tiles_seen = Array.new 
        tiles_to_check = Array.new << [start, []]
        #format of tiles_to check:
        # [[x,y],[[a,b],[c,d]...]]
        # a,b   c,d are all older
        # tiles
        path = nil
        while tiles_to_check.length > 0 do
          tiles_to_check.sort { |f,s| f[1].size <=> s[1].size }
          current_tile = tiles_to_check.delete_at(0)
          if current_tile[0] == dest 
            path = current_tile[1] + [current_tile[0]]
            break
          end
          x,y = current_tile[0]
          if settings.map.tile_at(x,y) == :empty 
            unless tiles_seen.include? current_tile[0]
              tiles_seen << current_tile[0]
              rest_of_path = current_tile[1] + [[x,y]]
              #puts "Rest of path is #{rest_of_path.inspect}"
              tiles_to_check << [[x+1,y],rest_of_path]
              tiles_to_check << [[x-1,y],rest_of_path]
              tiles_to_check << [[x,y+1],rest_of_path]
              tiles_to_check << [[x,y-1],rest_of_path]
            end
          end
        end
        return path
      end

      #set up this game.
      #TODO this won't work because we need to give the right player name
      def set_initial_state characters, first
        $LOGGER.info "Setting up the initial state of the game."
        @state = State.new characters
        @current_move = first
        calculate_shadows "LOL"
      end

      #set up the shadow map. This needs to be called every time the board changes.
      def calculate_shadows player_name
        @shadows.reset_shadows
        @state.chars.each do |character|
          if character.owner == player_name
            @shadows.do_fov *(character.location+[5])
          end
        end
      end

      def start
        $LOGGER.debug "Game is starting."
        @mode = :in_progress
      end
    end
  end
end
