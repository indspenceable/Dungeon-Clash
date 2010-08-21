require 'game_map'

module DCGame
  # This is the type of thing that once the game starts, you can't change.
  # SO - the map but not the state of the map.
  class GameSettings
    attr_accessor :width, :height, :map, :shadows
    def initialize map
      @map = map
      @width = map.width
      @heigh = map.height
    end
  end
end
