# Contains the DCGame::Character class.

module DCGame
  # This represents a character in either a local instance or a server instance of a game.
  class Character
    # The name of this unit's owner.
    attr_reader :owner
    # The name of this units class.
    attr_reader :class
    # A list of this units moves
    attr_reader :moves
    # This units location
    attr_reader :location
    # A unique id number for this unit, shared by the server
    # and all the clients.
    attr_reader :c_id
    @@c_id = 0

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
      @c_id = (@@c_id += 1) 
    end
  end
end
