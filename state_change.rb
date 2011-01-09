module DCGame
  #classes in this module represent a change in game state
  # they have a dual purpose - they change the state on being activated
  # but they also help animate that change.
  module StateChange
    class StateChange
      def masks_character? c
        false
      end
      def finished?
        true
      end
      def step
      end
    end
    class Death < StateChange
      def initialize unit_id
        @unit_id = unit_id
      end
      def activate state
        state.kill_character_by_c_id(@unit_id)
      end
    end
    class Heal < StateChange
      def initialize unit_id, amt
        puts "AMT is #{amt} unit is #{unit_id}"
        @amt = amt
        @unit_id = unit_id
      end
      def activate state
        char = state.character_by_c_id(@unit_id)
        char.health += @amt
        char.health = char.max_health if char.health > char.max_health
      end
    end
    class Movement < StateChange
      attr_accessor :unit
      def initialize path, unit
        @unit = unit
        @path = path
        @current_step = 0
      end
      def current_location
        @path[@current_step]
      end
      def step
        @current_step += 1
      end
      def finished?
        @current_step >= @path.size-1
      end
      def activate state
        state.character_by_c_id(@unit).location = @path.last
      end
      def masks_character? c
        return c.c_id == @unit
      end
    end
    class DealDamage < StateChange
      def initialize amt, char
        @unit = char
        @ammount_to_damage = amt
      end
      def activate state
        state.character_by_c_id(@unit).health -= @ammount_to_damage
      end
    end
    class IncreaseFatigue < StateChange
      def initialize amt, char
        @unit = char
        @ammount_to_increase_fatigue = amt
      end
      def activate state
        state.increase_fatigue state.character_by_c_id(@unit), @ammount_to_increase_fatigue
      end
    end
    class ChooseNextCharacter < StateChange
      def activate state
        state.choose_next_character_to_move!
      end
    end
    class TireCurrentCharacter < StateChange
      def activate state
        state.movable = false
      end
    end
  end
end
