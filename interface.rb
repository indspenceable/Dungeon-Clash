require 'rubygems'
require 'rubygame'

include Rubygame

module DCGame
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

    SPRITE_STRETCH = 8

    TILE_WIDTH = SPRITE_WIDTH*SPRITE_STRETCH
    TILE_HEIGHT = SPRITE_HEIGHT*SPRITE_STRETCH

    TILES_WIDE = 10
    TILES_HIGH = 10

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

      #screen
      @screen = Screen.new [TILE_WIDTH * TILES_WIDE, TILE_HEIGHT * TILES_HIGH]
      @name = @connection.name

      @offset = [0,0]
    end

    def draw target
      @screen.fill [255, 255, 255]
      if target.is_a? Client::Game
        draw_game @connection.game
      end
      @screen.update
    end

    def draw_map
      game = @connection.game
      TILES_WIDE.times do |x|
        TILES_HIGH.times do |y|
          if game.map.tile_at(@offset[0]+x,@offset[1]+y) != :empty
            draw_tile 0,0, [x,y]
          else
            draw_tile 12,0, [x,y]
          end
        end
      end
      return
      unless @cached_map
        game = @connection.game
        @prerendered_map = Surface.new [TILE_WIDTH * TILES_WIDE, TILE_HEIGHT * TILES_HIGH]
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

    def draw_units
      game = @connection.game
      #game.state.chars.each_pair do |key, val| 

      game.map.width.times do |x|
        game.map.height.times do |y|
          if on_screen? x,y
            unless game.shadows.lit?(x,y)
              draw_tile 5,9, screen_location(x,y)
            else
              if game.state.is_character_at? x,y
                current_character = game.state.character_at x,y
                if current_character.owner == @name
                  if game.state.current_character == current_character
                    draw_sprite 0,16, screen_location(x,y)
                  else
                    draw_sprite 1,6, screen_location(x,y)
                  end
                else
                  if game.state.current_character == current_character
                    draw_sprite 0,7, screen_location(x,y)
                  else
                    draw_sprite 1,7, screen_location(x,y)
                  end
                end
              end
            end
          end
        end
      end
    end

    def draw_game game
      @screen.fill [0,0,0]
      draw_map

      #TITLE
      case @connection.game.mode
      when :select_characters
        @text.render("Select your characters.", true, [0,0,0]).blit @screen, [0,0]
        offset = 40
        game.players.each do |p|
          @text.render(p + "is finalized: #{game.finalized_players.player_finalized? p}", true, [0,0,0]).blit @screen, [0, offset]
          offset+=30
        end
      when :lobby
        @text.render("Waiting for more players.", true, [0,0,0]).blit @screen, [0,0]
        offset = 40
        game.players.each do |p|
          @text.render(p , true, [0,0,0]).blit @screen, [0, offset]
          offset+=30
        end
      when :in_progress
        @text.render("Game is running.", true, [0,0,0]).blit @screen, [0,0]
        draw_units
        #draw_shadows
        draw_tile 0,9, [@cursor[0]-@offset[0], @cursor[1]-@offset[1]]
        draw_path
      end
    end

    def draw_path
      if @path
        @path.each do |l|
          draw_sprite 3,3,screen_location(*l)
        end
      end
    end

    def draw_sprite sx,sy,location, target=@screen
      x,y = location
      rtn  = Surface.new [SPRITE_WIDTH, SPRITE_HEIGHT]
      @sprite_sheet.blit rtn, [0,0], [sx*SPRITE_WIDTH, sy*SPRITE_HEIGHT, SPRITE_WIDTH, SPRITE_HEIGHT]
      rtn = rtn.zoom SPRITE_STRETCH, false
      rtn.set_colorkey @sprite_sheet.colorkey
      rtn.blit target, [TILE_WIDTH*x,TILE_HEIGHT*y]
    end
    def draw_tile sx,sy,location, target=@screen
      x,y = location
      rtn  = Surface.new [SPRITE_WIDTH, SPRITE_HEIGHT]
      @dungeon.blit rtn, [0,0], [sx*SPRITE_WIDTH, sy*SPRITE_HEIGHT, SPRITE_WIDTH, SPRITE_HEIGHT]
      rtn = rtn.zoom SPRITE_STRETCH, false
      rtn.set_colorkey @dungeon.colorkey
      rtn.blit target, [TILE_WIDTH*x,TILE_HEIGHT*y]
    end

    #-------------------------------
    #        INPUT METHODS
    #-------------------------------

    def initialize_input
      @cursor = [0,0]
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

    def process_event e 
      if e.is_a? Events::KeyPressed
        @cursor[1] += 1 if e.key == :j
        @cursor[1] -= 1 if e.key == :k
        @cursor[0] += 1 if e.key == :l
        @cursor[0] -= 1 if e.key == :h
        if e.key == :m
          if @path
            # Send a "DO MOVE" message
            #puts @path.inspect
            @connection.send_object Message::MoveCurrentCharacter.new @path 
          else
            # Calculate path to target
            @path = @connection.game.calculate_path_between @connection.game.state.current_character.location, @cursor
          end
        end

        #@connection.send_object Message::MoveCurrentCharacter.new @cursor if e.key == :k

        normalize_cursor
      end
    end
  end
end
