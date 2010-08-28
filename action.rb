require 'state_change'
module DCGame
  module Action
    #an action has an enact method, which applies it to the game, and then returns a StateChange
    class EndTurn
      def enact game
        game.state.choose_next_character_to_move
        state_changes = [StateChange::ChangeCurrentCharacter.new game.state.current_character.c_id]
      end
    end

    class Attack
      def enact game 
      end
    end

    class Movement
      def initialize path
        @path = path
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

        # we need to increase this character's fatigue
        # TODO Design question - Should you be penalized for the ammount you 
        # try to move? or the ammount you move?
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
