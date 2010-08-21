module DCGame
  class GameMap

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
    
    def tile_at x,y
      return nil if x < 0 || y < 0 || x >= @width || y >= @height
      return @map[x][y] 
    end

    def generate
      @map.each_index do |x|
        @map[x].each_index do |y|
          rand(4) > 0 ? @map[x][y] = :empty : @map[x][y] = :full
        end
      end
    end

  end
end
