require 'board'
require 'shadow_map'
require 'character'
require 'action'

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

    #Right now this just holds characters.
    # In fact you can just get the list, but if you want a shortcut (like, 
    # is there a character at this location?) then that is a possibility
    # as well.
    class State
      attr_accessor :characters, :movable
      def initialize setup
        @characters = setup
        @current_character = -1
        @movable = true
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
      def current_character
        @characters.each do |c|
          return c if c.c_id == @current_character
        end
        $LOGGER.warn "Trying to fetch current character, but #{@current_character} set."
        nil
      end
      def player_for_current_character
        current_character.owner
      end 
      def character_by_c_id c_id
        @characters.find{|c| c.c_id == c_id}
      end

      def choose_next_character_to_move!
        @characters.each{ |c| c.fatigue -= 1 } until @characters.any? { |c| c.fatigue == 0 } 
        chars_with_zero_fatigue = @characters.find_all{ |c| c.fatigue == 0 }
        chars_with_zero_fatigue.each{ |c| c.tie_fatigue -= 1 } until chars_with_zero_fatigue.any? { |c| c.tie_fatigue == 0 }
        @current_character = @characters.find{ |c| (c.fatigue == 0) && (c.tie_fatigue == 0) }.c_id
      end

      def increase_fatigue character, amt
        character.fatigue += amt
        character.tie_fatigue = 0
        character.tie_fatigue += 1 while @characters.any? do |c| 
          c.fatigue == character.fatigue && c.tie_fatigue > character.tie_fatigue
        end
        puts "Character's fatigue is set to be: #{character.fatigue} fatigue (#{character.tie_fatigue})"
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

      attr_accessor :state

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
  module Server
    class Game < Games::Base
      def initialize name
        super(name, Board.new(15,15))
      end

      # Inform the game that a player has joined.
      #TODO Make this work with a string, using PlayerIndex
      def add_player player
        super
        if full?
          begin_character_selection
        else 
          $LOGGER.info "Informing those connected that #{player} has joined."
          @players.reject{|p| p==player}.each do |p|
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
          p.owner.send_object Message::Game.new(:begin_character_selection, players.reject{ |pl| p==pl}.collect{ |pl| pl.name})
        end
      end

      # Tell the game that this player is finished choosing their character.
      def set_player_finalized player

        @finalized_players.set_player_finalized player.name, true

        #generate random characters.
        5.times do
          loc = [rand(@map.width), rand(@map.height)]
          loc = [rand(@map.width), rand(@map.height)] until passable? loc
          @state.characters << (Character.new player.name, "soldier", [], loc)
        end

        if @finalized_players.all_players_finalized?

          $LOGGER.info "All Players are finalized, so the game is starting."
          #@state.set_current_character_by_c_id @state.characters[rand @state.characters.length].c_id
          @state.characters.size.downto(1) { |n| @state.characters.push @state.characters.delete_at(rand(n)) }
          @state.characters.size.times do |n|
            @state.characters[n].fatigue = 0
            @state.characters[n].tie_fatigue = n
          end

          @state.choose_next_character_to_move!

          players.each do |p|
            p.owner.send_object Message::StartGame.new @state
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
      #def passable? x,y
      #   map.tile_at(x,y) != :empty 
      #end

      def action act
        state_changes = act.enact self  
        state_changes.each do |sc|
          sc.activate @state
        end
        @players.each do |p|
          p.owner.send_object Message::Game.new(:accept_state_changes, state_changes)
        end
      end

      def cost_per_move character; 1 end
    end
  end

  module Client
    class Game < Games::Base

      attr_reader :shadows

      def initialize name, pname, players, map
        super(name, map)
        $LOGGER.info "Constructing a game_interface."
        @player_name = pname
        @shadows = ShadowMap.new @map

        @state_change_queue = Array.new
      end

      # This makes the game being character selection mode. 
      def begin_character_selection player_list
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
        return path unless would_path_through?(*dest)
        while tiles_to_check.length > 0 do
          tiles_to_check.sort { |f,s| f[1].size <=> s[1].size }
          current_tile = tiles_to_check.delete_at(0)
          if current_tile[0] == dest 
            path = current_tile[1] + [current_tile[0]]
            break
          end
          x,y = current_tile[0]
          if would_path_through?(x,y)
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

      def would_path_through?(x,y)
        return false if @map.tile_at(x,y) != :empty
        if @shadows.lit?(x,y)
          if @state.is_character_at?(x,y)
            return false if @state.character_at(x,y).owner != @player_name
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
