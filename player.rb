module DCGame
  class Player
    attr_accessor :owner, :name
    def initialize(name,owner)
      @owner = owner
      @name = name
    end
    def to_s
      return "[Player: #{@name}]"
    end
  end
end
