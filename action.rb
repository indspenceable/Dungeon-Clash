require 'state_change'
require 'message'
require 'set'

module DCGame
  module Action
    # An action is something that the player does. Core examples are Movement, Attacking, and ending 
    # the turn. Any special abilities are actions as well. Subclassses of Action represent each 
    # different permutation. Actions talk to the game state, the interface, AND the server.
    # so, they could potentially be restructured? But I'm unsure how would make sense.
    class Action
      #Get the list of tiles to highlight in the interface.
      def highlights
        @tiles
      end
      #Does the player need to confirm this action? Examples where this will be overridden - ENDTURN, WAIT
      def self.no_confirm
        false
      end
      #Figure out how the gamestate will change, by looking at the gamestate on the server. Generate
      # the appropriate series of StateChange s.
      def enact game
        raise "enact not overwritten for #{self.class}."
      end
      # Delagate to the classes #prepare_action. Return self.
      def prep cursor, game
        prepare_action cursor, game
        self
      end
      #an action has an enact method, which applies it to the game, and then returns a StateChange
      def enact game
        raise "enact method not overwritten in #{self.class}"
      end
      def prepare_action cursor, game
        raise "prepare_action method not overwritten in #{self.class}"
      end

      def self.primary_action
        true
      end
    end
    
    class Teleport < Action
      def initialize game
        @tiles = Set.new
        cx,cy = game.state.current_character.location
        game.map.width.times do |x| 
          game.map.height.times do |y|
            dist = (x-cx).abs + (y-cy).abs 
            if dist > 3 && dist < 6 && game.would_path_through?(false, x,y)
              @tiles << [x,y]
            end
          end
        end
      end
      def prepare_action cursor, game
        @target = [*cursor]
      end
      def enact game
        state_changes = Array.new
        cur_location = game.state.current_character.location
        unless game.state.is_character_at?(*@target)
          state_changes << StateChange::Movement.new([cur_location,@target]*10, game.state.current_character.c_id)
        end
        state_changes << StateChange::IncreaseFatigue.new(10, game.state.current_character.c_id)
      end
    end
    class EndTurn < Action
      def initialize game
        @highlights = 0
      end
      def self.no_confirm
        true
      end
      def self.primary_action
        false
      end
      def enact game
        #game.state.choose_next_character_to_move!
        state_changes = [StateChange::ChooseNextCharacter.new]
      end
    end

    class Attack < Action
      def initialize game
        x,y = game.state.current_character.location
        tiles_to_check = Array.new << [x+1,y] << [x-1,y] << [x,y+1] << [x,y-1]
        @tiles = Set.new
        tiles_to_check.each do |t|
          x,y = t
          @tiles << t if game.state.is_character_at?(x,y)
        end
      end
      def prepare_action cursor, game
        @target_id = game.state.character_at(*cursor).c_id
      end
      def enact game 
        #game.state.character_by_c_id(@target_id).health -= 3
        [StateChange::DealDamage.new(3,@target_id), StateChange::IncreaseFatigue.new(3, game.state.current_character.c_id)]
      end
      def self.primary_action
        false
      end
    end
    class Movement < Action
      def initialize game
        open_list = Array.new << [game.state.current_character.location, []]
        closed_list = Array.new
        @tiles = Set.new
        while open_list.size > 0 && open_list.first[1].size <= 5
          current = open_list.delete_at(0)
          l = current[0]
          closed_list << l
          if game.would_path_through? true, *l
            @tiles << l
            x,y = l
            current_trail = current[1]
            open_list << [[x+1,y],current_trail + [l]] unless closed_list.include? [x+1,y]
            open_list << [[x-1,y],current_trail + [l]] unless closed_list.include? [x-1,y]
            open_list << [[x,y+1],current_trail + [l]] unless closed_list.include? [x,y+1]
            open_list << [[x,y-1],current_trail + [l]] unless closed_list.include? [x,y-1]
          end
          open_list.sort { |a,b| b[1].length <=> a[1].length }
        end
      end
      def prepare_action cursor, game
        @path = game.calculate_path_between game.state.current_character.location, cursor
      end
      def enact game
        state_changes = Array.new
        
        path = @path
        $LOGGER.info "Moving on path right now."
        current_character_location = game.state.current_character.location
        $LOGGER.warn "Current character is at #{game.state.current_character.location.inspect} while the path is starting at #{path.first.inspect}..." if game.state.current_character.location != path.first
        last_passable_space = game.state.current_character.location
        success = true
        path.each do |l|
          if game.passable? l, game.state.player_for_current_character
            current_character_location = l
            #actual_move_path << l
            last_passable_space = l if game.passable?(l)
          else
            success = false 
            break
          end
        end
        actual_move_path = []
        x = false
        path.each do |l|
          unless x
            actual_move_path << l
            x = (l==last_passable_space)
          end
        end

        #game.state.increase_fatigue(game.state.current_character,
        #                            actual_move_path.size*game.cost_per_move(game.state.current_character))
        

        #game.state.current_character.location = actual_move_path.last
        state_changes << StateChange::Movement.new(actual_move_path, game.state.current_character.c_id)
        state_changes << StateChange::IncreaseFatigue.new(actual_move_path.size*game.cost_per_move(game.state.current_character), game.state.current_character.c_id)

        if success
          state_changes << StateChange::TireCurrentCharacter.new()
        else
          #game.state.choose_next_character_to_move!
          #state_changes << StateChange::ChangeCurrentCharacter.new(game.state.current_character.c_id)
          state_changes << StateChange::ChooseNextCharacter.new()
        end
        state_changes
      end
    end
  end
end
