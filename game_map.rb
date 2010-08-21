module DCGame
  class GameMap


    attr_reader :width
    attr_reader :height

    def initialize width, height
      @width = width
      @height = height
      @map = Array.new(width) {|x|
        Array.new(height) {
          :empty
        }
      }
    end

    def generate
      @map.each_index do |x|
        @map[x].each_index do |y|
          rand()%4 > 0 ? @map[x][y] = :empty : @map[x][y] = :full
        end
      end
    end

  end
end
