module DCGame
  #classes in this module represent a change in game state
  # they have a dual purpose - they change the state on being activated
  # but they also help animate that change.
  module StateChange
    class StateChange
      def masks_character? c
        return false
      end
    end
    class Movement < StateChange
      #TODO there is a bug when you try to move and the last square you can land on before bumping into a baddie is actually occupied...
      FRAMES_PER_STEP = 10
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
        puts "STEP"
        @current_step += 1
      end
      def finished?
        @current_step >= @path.size-1
      end
      def activate state
        unit.location = @path.last
      end
      def masks_character? c
        return c == @unit
      end
    end
    class ChangeCurrentCharacter
      def initialize new_char
        @new_current_character = new_char
      end
      def step
      end
      def finished?
        true
      end
      def activate state
        puts "ACTIVATING"
        state.set_current_character_by_c_id @new_current_character
      end
    end
  end
end
