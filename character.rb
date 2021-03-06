# Contains the DCGame::Character class.

#Namespace for dungeonclash
module DCGame
   # This represents a character in either a local instance or a server instance of a game.
  class Character
    # The name of this unit's owner.
    attr_reader :owner
    # The name of this units class.
    attr_reader :job
    # A list of this units moves
    attr_reader :moves
    # This units location
    attr_accessor :location
    # A unique id number for this unit, shared by the server
    # and all the clients.
    attr_reader :c_id
    # These keep track of turn order.
    attr_accessor :fatigue, :tie_fatigue
    attr_accessor :health, :max_health

    #@@c_id = 0
    # Create a class. Provide the unmutable information and starting statistics for this character.
    # [owner] The name of the player that owns this character
    # [job] the name of the class this character belongs to
    # [moves] a list of moves that this character can do.
    # [location] the x,y position of this character
    def initialize owner, job, moves, location
      @owner = owner
      @job = job
      @moves = moves
      @location = location
      @health = 10
      @max_health = 10
      @c_id = 0
    end

    def set_c_id x
      @c_id = x
    end
  end
end
