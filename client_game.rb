require './game.rb'
module DCGame
  module Client
    class Game < Games::Base

      attr_reader :shadows
      attr_reader :my_character_locations

      def initialize name, pname, players, map
        super(name, map)
        $LOGGER.info "Constructing a client side game."
        @player_name = pname
        @shadows = ShadowMap.new @map

        @state_change_queue = Array.new
      end

      # This makes the game being character selection mode. 
      def begin_character_selection combined_arguments
        player_list, @my_character_locations = combined_arguments

        @players = player_list
        $LOGGER.debug "Game is moving into character selection phase. Other players are #{@players.inspect}"
        @mode = :select_characters
        @finalized_players.clear_players

        #this is the part where you choose players
        @players.each do |p|
          @finalized_players.set_player_finalized p, false
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
        $LOGGER.info "Finding a path between #{start.inspect} and #{dest.inspect}"
        tiles_seen = Array.new 
        tiles_to_check = Array.new << [start, []]

        #TODO check dest.

        #format of tiles_to check:
        # [[x,y],[[a,b],[c,d]...]]
        # a,b   c,d are all older
        # tiles
        path = nil
        return path unless would_path_through?(true, *dest)
        while tiles_to_check.length > 0 do
          tiles_to_check.sort { |f,s| f[1].size <=> s[1].size }
          current_tile = tiles_to_check.delete_at(0)
          if current_tile[0] == dest 
            path = current_tile[1] + [current_tile[0]]
            break
          end
          x,y = current_tile[0]
          if would_path_through?(true,x,y)
            unless tiles_seen.include? current_tile[0]
              tiles_seen << current_tile[0]
              rest_of_path = current_tile[1] + [[x,y]]

              tiles_to_check << [[x+1,y],rest_of_path]
              tiles_to_check << [[x-1,y],rest_of_path]
              tiles_to_check << [[x,y+1],rest_of_path]
              tiles_to_check << [[x,y-1],rest_of_path]
            end
          end
        end
        return path
      end


      def would_path_through?(ignore_my_characters, x,y)
        return false if @map.tile_at(x,y) != :empty
        if @shadows.lit?(x,y)
          if @state.is_character_at?(x,y)
            return false unless ignore_my_characters && @state.character_at(x,y).owner == @player_name
          end
        end
        true
      end

      #set up this game.
      #TODO this won't work because we need to give the right player name
      def set_initial_state state
        $LOGGER.info "Setting up the initial state of the game."
        @state = state
        calculate_shadows @player_name
      end

      #set up the shadow map. This needs to be called every time the board changes.
      def calculate_shadows player_name
        @shadows.reset_shadows
        @state.characters.each do |character|
          if character.owner == player_name
            @shadows.do_fov *(character.location+[5])
          end
        end
      end

      def start
        $LOGGER.debug "Game is starting."
        @mode = :in_progress
      end

      def enqueue_state_change sc
        @state_change_queue << sc
      end
      def get_next_state_change
        return nil if @state_change_queue.length == 0
        @state_change_queue.delete_at(0)
      end

      def accept_state_changes list
        $LOGGER.warn "ACCEPT STATE_CHANGES."
        list.each do |sc|
          enqueue_state_change sc
        end
      end

      #TODO rename this to move_character
      def move_unit args
        $LOGGER.warn "MOVE UNITS"
        path, new_current_character = *args
        #puts "#{path.inspect} is path"
        enqueue_state_change StateChange::Movement.new(path, @state.current_character)
        #if @state.current_character.c_id != new_current_character
        enqueue_state_change StateChange::ChangeCurrentCharacter.new(new_current_character)
        #else
        #end
      end
    end
  end
end
