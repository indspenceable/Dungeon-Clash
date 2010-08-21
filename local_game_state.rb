module DCGame
  class LocalGameState
    attr_accessor :chars
    def initialize list
      @chars = list
    end

    def is_character_at? x,y
      @chars.any?{|c| c.location == [x,y]}
    end

    def character_at x,y
      @chars.find{|c| c.location == [x,y]}
    end

  end
end
