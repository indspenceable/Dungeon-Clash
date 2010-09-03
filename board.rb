module DCGame
  class Board

    attr_reader :width
    attr_reader :height

    def initialize width, height
      @width = width
      @height = height
      @map = Array.new(width) do
        Array.new(height) do
          :empty
        end
      end
      generate
    end
    
    # Get the contents of the tile at a location.
    def tile_at x,y
      return nil if x < 0 || y < 0 || x >= @width || y >= @height
      return @map[x][y] 
    end

    # Generate a random map. This will be deprecated when loading maps
    # is possible.
    def generate
      @map.each_index do |x|
        @map[x].each_index do |y|
          rand(4) > 0 ? @map[x][y] = :empty : @map[x][y] = :full
        end
      end
    end

    # Given a map, it has a number of players that are expected to play on it. This
    # should depend on the map loaded, so for the random map we're just using 2.
    def player_capacity
      2
    end
  end
end
