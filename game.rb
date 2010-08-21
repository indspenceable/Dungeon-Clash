# Contains DCGame::Game
require 'game_settings'
require 'character.rb'
require 'game_map.rb'

module DCGame

  # Represents a game on the serverside. Should be moved to DCGame::Server::Game
  # so as to remove the name conflict with the local concept of a  game
  class Game
    # The list of players for this game
    attr_accessor :players
    # The name of this game
    attr_accessor :name
    # The immutable settings of this game.
    attr_accessor :settings

    # Setup a game.
    #TODO this should be improved to take the dimensions and/or a filename
    # as arguments.
    def initialize name 
      @name = name
      @players = []
      @mode = :lobby
      map = GameMap.new 25, 25
      map.generate
      @settings = GameSettings.new map
      
      reset_variables
    end


    def reset_variables
      @characters = Array.new
      @finalized_players = Hash.new
    end
    private :reset_variables

    # Inform the game that a player has joined.
    def add_player player
      @players << player
      $LOGGER.info "Player has joined."
      if full?
        begin_character_selection
      else 
        players.reject{|p| p==player}.each do |p|
          $LOGGER.info "We are sending the update that there is a new player to: #{p.name} about #{player.name}"
          p.owner.send_object Message::PlayerHasJoined.new connection.player.name
        end
      end
    end

    # Tell the game that this player is finished choosing their character.
    def finalize_player player
      $LOGGER.debug "We are calling finalize_player on the server side."
      @finalized_players[player] = true

      5.times do
        loc = [rand(10), rand(10)]
        loc = [rand(10), rand(10)] while @characters.any?{|c| c.location == loc} || @settings.map.tile_at(*loc)!= :empty

        @characters << (Character.new player.name, "soldier", [], loc)
        puts "Created a character at #{loc}."
      end

      $LOGGER.info "Are all players finalized? #{@finalized_players.values}"
      return all_players_finalized unless @finalized_players.values.include? false 

      players.each do |p|
        puts "Sending a 'finalized player message'"
        p.owner.send_object Message::PlayerFinalized.new player.name
      end
    end

    # When all players are finalized, this method gets called.
    def all_players_finalized
      puts  "ALL PLAYERS ARE FINALIZED..."

      msg = Message::StartGame.new @characters, @characters[rand @characters.length].c_id
      players.each do |p|
        p.owner.send_object msg
      end
    end

    # For whatever reason, this game must return to lobby and restart.
    def return_to_lobby 
      puts "Going back to lobby"
      @mode = :lobby
      @finalized_players = nil
      reset_variables
    end

    # Player has left the game.
    def remove_player p
      puts "We are removing <#{p.name}>"
      players.delete p
      players.each do |player|
        player.owner.send_object Message::PlayerLeft.new p.name
      end
      return_to_lobby if started?
    end

    # If the game has started
    def started?
      @mode!=:lobby
    end

    # All the players have joined, so we've started character selection.
    def begin_character_selection
      puts "Character Selection"
      @mode = :select_charactes
      players.each do |p|
        @finalized_players[p] = false
        puts "Sending out a 'start game'"
        p.owner.send_object Message::SelectCharacters.new players.reject{ |pl| p==pl}.collect{ |pl| pl.name}
      end
    end


    # is the game full? if so, its probably going to jump to Game.begin_character_selection
    def full?
      $LOGGER.info "So far, #{players.length} players are in the game."
      players.length==2
    end
  end
end
