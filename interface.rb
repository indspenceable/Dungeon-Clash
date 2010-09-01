require 'rubygems'
require 'rubygame'
require 'state_change'
require 'action'

include Rubygame

module DCGame
  class InputAction
    attr_accessor :klass
    attr_reader :key
    def initialize keysym, klass 
      @klass = klass
      @key = keysym
    end
    def requires_movable
      @klass.requires_movable
    end
  end
  class Interface
    def initialize connect
      @connection = connect
      initialize_output
      initialize_input
    end
    #-------------------------------
    #        CONSTANTS
    #-------------------------------

    SPRITE_HEIGHT = 8
    SPRITE_WIDTH = 8

    SPRITE_STRETCH = 4

    TILE_WIDTH = SPRITE_WIDTH*SPRITE_STRETCH
    TILE_HEIGHT = SPRITE_HEIGHT*SPRITE_STRETCH

    TILES_WIDE = 15
    TILES_HIGH = 15

    #-------------------------------
    #        DISPLAY METHODS
    #-------------------------------

    def initialize_output
      # TEXT
      TTF.setup
      @text = TTF.new('font.ttf',12)

      #sprites
      @sprite_sheet = Surface.load 'sprite.png'
      @sprite_sheet.set_colorkey [0, 255, 255]
      @dungeon = Surface.load 'dungeon.png'
      @dungeon.set_colorkey [255,255,255]
      @sprite_cache = Hash.new

      #screen
      @screen = Screen.new [TILE_WIDTH * TILES_WIDE, TILE_HEIGHT * TILES_HIGH + 8]
      @name = @connection.name

      @offset = [0,0]
      @pending_action = nil
    end

    def draw target
      #if we need a state_change, ask for one
      @state_change = @connection.game.get_next_state_change unless @state_change
      #assuming we have one, if its finished activate it and ask for another
      while @state_change && @state_change.finished? 
        @state_change.activate @connection.game.state
        @connection.game.calculate_shadows @name
        @state_change = @connection.game.get_next_state_change
      end
      #if at this point we have one, then step.
      @state_change.step if @state_change

      @screen.fill [255, 255, 255]
      if target.is_a? Client::Game
        draw_game
      end
      @screen.update
    end

    def draw_map
      unless @prerendered_map
        game = @connection.game
        @prerendered_map = Surface.new [TILE_WIDTH * game.map.width, TILE_HEIGHT * game.map.height]
        game.map.width.times do |x|
          game.map.height.times do |y|
            if game.map.tile_at(x,y) != :empty
              draw_tile 0,0, [x, y], @prerendered_map
            else
              draw_tile 12,0, [x, y], @prerendered_map
            end
          end
        end
      end
      @prerendered_map.blit @screen, [@offset[0]*-TILE_WIDTH, @offset[1]*-TILE_HEIGHT]
    end

    def on_screen? x,y
      x >= @offset[0] && x < @offset[0]+TILES_WIDE &&
        y >= @offset[1] && y < @offset[1]+TILES_WIDE
    end

    #transforms a map location to screen location
    def screen_location x,y
      [x-@offset[0],y-@offset[1]] 
    end

    def get_sprite_for_character character
      if @connection.game.state.current_character == character
        if character.owner == @name
          [0,7]
        else
          #their selected guy
          [1,7]
        end
      else
        if character.owner == @name
          [5,6]
        else
          #their guys
          [6,6]
        end
      end
    end

    #TODO rename to draw_characters
    def draw_units
      game = @connection.game
      #game.state.chars.each_pair do |key, val| 
      game.map.width.times do |x|
        game.map.height.times do |y|
          if on_screen? x,y
            if !game.shadows.lit?(x,y)
              draw_tile 5,9, screen_location(x,y)
            else
              #if game.state.is_character_at?(x,y) && @state_change && @state_change.is_a?(StateChange::Movement) && game.state.character_at(x,y) == @state_change.unit
              if character_to_draw?(x,y)
                current_character = game.state.character_at x,y
                cx,cy = get_sprite_for_character current_character 
                draw_sprite cx,cy,screen_location(x,y)
              end
            end
          end
        end
        if @state_change && @state_change.is_a?(StateChange::Movement)
          #current_character = game.state.character_at x,y
          current_character = game.state.character_by_c_id @state_change.unit
          cx,cy = get_sprite_for_character current_character 
          #puts "Current location is: #{@state_change.current_location.inspect}"
          x,y = @state_change.current_location
          draw_sprite cx,cy,screen_location(*@state_change.current_location) if game.shadows.lit?(x,y) || current_character.owner == @name
        end
      end
    end

    def character_to_draw?(x,y)
      return false unless @connection.game.state.is_character_at?(x,y)
      return false if @state_change && @state_change.masks_character?(@connection.game.state.character_at(x,y))
      return true
    end

    def draw_game
      @screen.fill [0,0,0]
      draw_map

      #TITLE
      case @connection.game.mode
      when :select_characters
        @text.render("Select your characters.", true, [0,0,0]).blit @screen, [0,0]
        offset = 40
        @connection.game.players.each do |p|
          @text.render(p.inspect + "is finalized: #{@connection.game.finalized_players.player_finalized? p}", true, [0,0,0]).blit @screen, [0, offset]
          offset+=30
        end
      when :lobby
        @text.render("Waiting for more players.", true, [0,0,0]).blit @screen, [0,0]
        offset = 40
        @connection.game.players.each do |p|
          @text.render(p , true, [0,0,0]).blit @screen, [0, offset]
          offset+=30
        end
      when :in_progress
        @text.render("Game is running.", true, [0,0,0]).blit @screen, [0,0]
        draw_units
        #draw_shadows
        # TODO Fix this - this should be streamlined. maybe keep draw path, but change draw_attack to
        # draw effect. 
        draw_path
        draw_pending_action
        draw_tile 0,9, [@cursor[0]-@offset[0], @cursor[1]-@offset[1]]
      end
    end

    def draw_path
      if @path
        @path.each do |l|
          draw_sprite 11,9,screen_location(*l)
        end
      end
    end

    def draw_pending_action
      if @pending_action
        @pending_action.highlights.each do |l|
          draw_tile 5,10,screen_location(*l)
        end
      end
    end

    def load_image_from_sprite_sheet sx,sy,target, ss
      $LOGGER.info("Creating sprite for #{ss.inspect} at x:#{sx}, y#{sy}")
      rtn  = Surface.new [SPRITE_WIDTH, SPRITE_HEIGHT]
      ss.blit rtn, [0,0], [sx*SPRITE_WIDTH, sy*SPRITE_HEIGHT, SPRITE_WIDTH, SPRITE_HEIGHT]
      rtn = rtn.zoom SPRITE_STRETCH, false
      rtn.set_colorkey ss.colorkey
    end
    def draw_from_sprite_sheet sx, sy, location, target, ss
      x,y = location
      (@sprite_cache[[sx,sy,ss]] ||= load_image_from_sprite_sheet sx,sy,target,ss).blit target, [TILE_WIDTH*x,TILE_HEIGHT*y]
    end

    def draw_sprite sx,sy,location, target=@screen
      draw_from_sprite_sheet sx,sy,location,target,@sprite_sheet
    end
    def draw_tile sx,sy,location, target=@screen
      draw_from_sprite_sheet sx,sy,location,target,@dungeon
    end

    #-------------------------------
    #        INPUT METHODS
    #-------------------------------

    def initialize_input
      @cursor = [0,0]
      @pending_action = nil
      @actions = [InputAction.new(:a,Action::Attack), InputAction.new(:m, Action::Movement)]
    end

    def normalize_cursor
      @cursor.each_index do |i|
        @cursor[i] = 0 if @cursor[i] < 0
      end
      @cursor[0] -= 1 while @cursor[0] >= @connection.game.map.width
      @cursor[1] -= 1 while @cursor[1] >= @connection.game.map.height

      @offset[0] -= 1 while @cursor[0] < @offset[0]
      @offset[1] -= 1 while @cursor[1] < @offset[1]
      @offset[0] += 1 while @cursor[0] >= (@offset[0] + TILES_WIDE)
      @offset[1] += 1 while @cursor[1] >= (@offset[1] + TILES_HIGH)
    end

    #TODO this needs to be refactored like whoa
    def process_event e 
      if e.is_a? Events::KeyPressed
        @cursor[1] += 1 if e.key == :j
        @cursor[1] -= 1 if e.key == :k
        @cursor[0] += 1 if e.key == :l
        @cursor[0] -= 1 if e.key == :h

        i_action = @actions.find{|a| a.key == e.key}
        if i_action && (@connection.game.state.movable || !i_action.requires_movable)
          if !@pending_action.is_a?(i_action.klass)
            @pending_action = i_action.klass.new @connection.game
          elsif @pending_action.highlights.include? @cursor
            @connection.send_object Message::Game.new(:action,@pending_action.prep(@cursor, @connection.game))
            @pending_action = nil
          end
        end
      end
      normalize_cursor
    end
  end
end
