require 'local_game_state'
require 'game_settings'
require 'character'
require 'shadow_map'


# This should probably actually be called local game
module DCGame
  class GameInterface
    #include KeyProcessor

    attr_accessor :name, :players, :settings
    attr_reader :mode, :state
    attr_reader :shadows

    def initialize name, pname, players, settings
      $LOGGER.info "Constructing a game_interface."
      # Eventually will be a LocalGameState
      @state = nil
      @name = name
      @player_name = pname
      @players = players
      @settings = settings
      @mode = :lobby
      @finalized_players = Hash.new
      @current_move = 0
      @shadows = ShadowMap.new @settings
    end

    def add_player player
      $LOGGER.info "Player joined: #{player}"
      @players << player
    end

    def select_characters pl_list
      @players = pl_list
      #$LOGGER.info "Game is character_selection phase. Players are #{@players.join ','}"
      $LOGGER.info "Game is moving into character selection phase. Other players are #{@players * ','}"

      @mode = :select_characters
      #this is the part where you choose players
      players.each do |p|
        @finalized_players[p] = false
      end
    end

    def return_to_lobby
      #puts "A player has quit, thus the game is returning to the lobby" 
      $LOGGER.info "The game is returning to lobby mode."
      @mode = :lobby
      @finalized_players = Hash.new
    end

    def finalize_player pname
      $LOGGER.info "Trying to finalize player: #{pname}"
      @finalized_players[pname] = true if players.include? pname
    end

    def finalized_player player
      return @finalized_players[player] if defined? @finalized_players
      false
    end

    def character_for_current_move
      @state.chars.each do |c|
        return c if c.c_id == @current_move
      end
      nil
    end
    
    def player_for_current_move
      character_for_current_move.owner
    end

    def calculate_path_between start, dest
      tiles_seen = Array.new 
      tiles_to_check = Array.new << [start, []]
      #format of tiles_to check:
      # [[x,y],[[a,b],[c,d]...]]
      # a,b   c,d are all older
      # tiles
      path = nil
      while tiles_to_check.length > 0 do
        tiles_to_check.sort { |f,s| f[1].size <=> s[1].size }
        current_tile = tiles_to_check.delete_at(0)
        if current_tile[0] == dest 
          path = current_tile[1] + [current_tile[0]]
          break
        end
        x,y = current_tile[0]
        if settings.map[x][y] == :empty 
          unless tiles_seen.include? current_tile[0]
            tiles_seen << current_tile[0]
            rest_of_path = current_tile[1] + [[x,y]]
            #puts "Rest of path is #{rest_of_path.inspect}"
            tiles_to_check << [[x+1,y],rest_of_path]
            tiles_to_check << [[x-1,y],rest_of_path]
            tiles_to_check << [[x,y+1],rest_of_path]
            tiles_to_check << [[x,y-1],rest_of_path]
          end
        end
      end
      return path
    end


    def set_initial_state characters, first
      $LOGGER.info "Setting up the initial state of the game."
      @state = LocalGameState.new characters
      @current_move = first
      calculate_shadows
    end

    def calculate_shadows
      @shadows.reset_shadows
      @state.chars.each do |character|
        if character.owner == @player_name
          @shadows.do_fov *(character.location+[5])
        end
      end
    end

    def start
      puts "We are actually starting the game now!"
      @mode = :in_progress
    end

    def current_character id
      @current_move = id
    end

    def my_turn?
      @state.my_character_at loc 
    end
  end
end

