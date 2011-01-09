require './board'
require './shadow_map'
require './character'
require './action'

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
        !@finalization_states.values.include? false
      end
    end

    # Right now this just holds characters.
    # In fact you can just get the list, but if you want a shortcut (like, 
    # is there a character at this location?) then that is a possibility
    # as well.
    class State
      attr_accessor :characters, :movable
      def initialize setup
        @characters = setup
        @current_character = -1
        @movable = true
        @dead_characters = Array.new
      end 
      def is_character_at? x,y
        @characters.any?{|c| c.location == [x,y]}
      end
      def character_at x,y
        @characters.find{|c| c.location == [x,y]}
      end
      def set_current_character_by_c_id new_c_id
        if @current_character == new_c_id
          @movable = false
        else
          @current_character = new_c_id
          @movable = true
        end
      end
      def initialize_current_character!
        @current_character = @characters[0].c_id
      end
      def current_character
        @characters.each do |c|
          return c if c.c_id == @current_character
        end
        #$LOGGER.warn "Trying to fetch current character, but #{@current_character} set."
        raise "Trying to fetch current character but invalide id: #{@current_character} was set."
        nil
      end
      def player_for_current_character
        current_character.owner
      end 
      def character_by_c_id c_id
        @characters.find{|c| c.c_id == c_id}
      end

      def choose_next_character_to_move!
        $LOGGER.info "Hit choose_next_character_to_move!"
        current = current_character
        @characters.each{ |c| c.fatigue -= 1 } until @characters.any? { |c| c.fatigue == 0 } 
        chars_with_zero_fatigue = @characters.find_all{ |c| c.fatigue == 0 }
        chars_with_zero_fatigue.each{ |c| c.tie_fatigue -= 1 } until chars_with_zero_fatigue.any?{ |c| c.tie_fatigue == 0 }
        @current_character = @characters.find{ |c| (c.fatigue == 0) && (c.tie_fatigue == 0) }.c_id
        @movable = true if current != current_character
        $LOGGER.info "We set the current to be #{@current_character}"
      end
      def increase_fatigue character, amt
        character.fatigue += amt
        character.tie_fatigue = 0
        character.tie_fatigue += 1 while @characters.any? do |c| 
          c.fatigue == character.fatigue && c.tie_fatigue > character.tie_fatigue
        end
        puts "Character's fatigue is set to be: #{character.fatigue} fatigue (#{character.tie_fatigue})"
      end
      def kill_character_by_c_id character_id
        puts "KILL CHARACTER"
        character_to_kill = character_by_c_id(character_id)
        @dead_characters << character_to_kill
        @characters.delete(character_to_kill)
        puts "There is a character at that characters location: #{is_character_at?(*character_to_kill.location)}"
      end
    end

    class CharacterTemplate
      attr_accessor :name, :sprite
      def initialize n, s_location
        @name = n
        @sprite = s_location
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
      # Options: lobby, character_selection, :in_progress
      attr_reader :mode

      #Hey, interaces need to see what players are finalized
      attr_accessor :finalized_players

      attr_accessor :state
      attr_reader :character_templates

      def sprite_location_for_class class_name
        @character_templates.find{|t| t.name == class_name}.sprite
      end

      # Games should all have these variables set.
      def initialize name, map
        #set meta data
        @name = name
        @players = Array.new
        @map = map

        # mode defaults to lobby
        @mode = :lobby
        @state = State.new []

        @finalized_players = PlayerFinalizationTracker.new

        @character_templates = [
          CharacterTemplate.new("devil",[0,9]),
          CharacterTemplate.new("ghost",[4,7])
        ]
      end


      def reset_variables
        @state = State.new []
        @finalized_players.clear_players
      end

      # is the game full? if so, its probably going to jump to Game.begin_character_selection
      def full?
        players.length == @map.player_capacity
      end

      def add_player player
        @players << player
        $LOGGER.info "Player has joined."
      end

      def passable? loc, player_name=nil
        return false if @map.tile_at(*loc) != :empty
        return @state.character_at(*loc).owner == player_name if @state.is_character_at? *loc 
        true
      end
    end
  end 
end
