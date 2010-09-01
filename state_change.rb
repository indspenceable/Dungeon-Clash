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
    class Movement < StateChange
      #FRAMES_PER_STEP = 10
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
    class ChangeCurrentCharacter < StateChange
      def initialize new_char
        @new_current_character = new_char
      end
      def activate state
        state.set_current_character_by_c_id @new_current_character
      end
    end
    class TireCurrentCharacter < StateChange
      def activate state
        $LOGGER.warn "HI!"
        state.movable = false
      end
    end
    class IncreaseFatigue < StateChange
    end
  end
end
