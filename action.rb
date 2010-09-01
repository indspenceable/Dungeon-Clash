require 'state_change'
require 'message'
module DCGame
  module Action
    class Action
      def highlights; @tiles end
      def initialize
        raise "initialize not overwritten for #{self.class}"
      end
      def enact game
        raise "enact not overwritten for #{self.class}."
      end
      def prep cursor, game
        raise "prep not overwritten for #{self.class}."
      end
    end


    #an action has an enact method, which applies it to the game, and then returns a StateChange
    class EndTurn < Action
      def enact game
        game.state.choose_next_character_to_move
        state_changes = [StateChange::ChangeCurrentCharacter.new game.state.current_character.c_id]
      end
    end

    class Attack < Action
      def initialize game
        x,y = game.state.current_character.location
        tiles_to_check = Array.new << [x+1,y] << [x-1,y] << [x,y+1] << [x,y-1]
        @tiles = Array.new
        tiles_to_check.each do |t|
          x,y = t
          @tiles << t if game.state.is_character_at?(x,y)
        end
      end
      def enact game 
      end
    end
    class Wait < Action
      def initialize game
        @tiles = [game.state.current_character.location]
      end
      def generate_action cursor, game
        Action::Wait.new
      end
      def enact game
        @current_character = game.state.current_character
        total = 0
        begin
          @current_character.increase_fatigue @current_character, 1
          total += 1
        end while @current_character == game.state.current_character
      end
    end

    class Movement < Action
      def initialize game
        open_list = Array.new << [game.state.current_character.location, []]
        closed_list = Array.new
        @tiles = Array.new
        while open_list.size > 0 && open_list.first[1].size <= 10
          current = open_list.delete_at(0)
          l = current[0]
          closed_list << l
          if game.would_path_through? *l
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
      def generate_action cursor, game
        @path = game.calculate_path_between game.state.current_character.location, cursor
        self
      end
      def enact game
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

        #TODO this should just call all of the state_changes activate methods
        # ????
        game.state.increase_fatigue(game.state.current_character,
                                    actual_move_path.size*game.cost_per_move(game.state.current_character))

        game.state.current_character.location = actual_move_path.last
        state_changes = Array.new << StateChange::Movement.new(actual_move_path, game.state.current_character.c_id)

        if success
          state_changes << StateChange::TireCurrentCharacter.new()
        else
          game.state.choose_next_character_to_move
          state_changes << StateChange::ChangeCurrentCharacter.new(game.state.current_character.c_id)
        end
        state_changes
      end
    end
  end
end
