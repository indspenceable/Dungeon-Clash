require 'rubygame'
require './state_change'
require './action'

include Rubygame

module DCGame
  class InputAction
    attr_accessor :klass
    attr_reader :key
    def initialize keysym, klass 
      @klass = klass
      @key = keysym
    end
    def secondary_action 
      @klass.secondary_action
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

    SPRITE_STRETCH = 6

    TILE_WIDTH = SPRITE_WIDTH*SPRITE_STRETCH
    TILE_HEIGHT = SPRITE_HEIGHT*SPRITE_STRETCH

    TILES_WIDE = 15
    TILES_HIGH = 15

    TEXT_SIZE = 12

    PANEL_ROWS = 3
    PANEL_HEIGHT = 3*12

    SCREEN_WIDTH = TILE_WIDTH * TILES_WIDE
    SCREEN_HEIGHT = TILE_HEIGHT*TILES_HIGH + PANEL_HEIGHT

    FOG_OF_WAR = [0,0,0]
    ACCETABLE_MOVE = [0,255,0]

    FRIEND = [0,150,255]
    FOE = [255,0,0]

    COLOR_BLACK = [0,0,0]
    COLOR_WHITE = [255,255,255]

    #-------------------------------
    #        DISPLAY METHODS
    #-------------------------------

    # Set up the display part of the interface
    # VHAAAT? THIS SHOULD BE ITS OWN CLASS?
    # BLASPHEMY.
    def initialize_output
      # TEXT
      TTF.setup
      @text = TTF.new('font.ttf',TEXT_SIZE)

      #sprites
      @sprite_sheet = Surface.load 'sprite.png'
      @sprite_sheet.set_colorkey [0, 255, 255]
      @dungeon = Surface.load 'dungeon.png'
      @dungeon.set_colorkey [255,255,255]
      @sprite_cache = Hash.new
      @color_cache = {}

      #screen
      @screen = Screen.new [SCREEN_WIDTH, SCREEN_HEIGHT]
      @name = @connection.name

      @offset = [0,0]
      @pending_action = nil
    end

    # Draw a gamestate
    def draw
      #if we need a state_change, ask for one
      @state_change = @connection.game.get_next_state_change unless @state_change
      #assuming we have one, if its finished activate it and ask for another
      while @state_change && @state_change.finished? 
        @state_change.activate @connection.game.state
        @connection.game.calculate_shadows @name
        @state_change = @connection.game.get_next_state_change
        @panel = nil
      end
      #if at this point we have one, then step.
      @state_change.step if @state_change

      @screen.fill [255, 255, 255]
      draw_game
      @screen.update
    end

    # Draw the map
    def draw_map
      #TODO -seperate this into its own method.
      unless @prerendered_map
        game = @connection.game
        @prerendered_map = Surface.new [TILE_WIDTH * game.map.width, TILE_HEIGHT * game.map.height]
        game.map.width.times do |x|
          game.map.height.times do |y|
            if game.map.tile_at(x,y) != :empty
              #TODO fix this
              draw_tile 0,0, [x, y], @prerendered_map
            else
              #TODO Fix this
              draw_tile 12,0, [x, y], @prerendered_map
            end
          end
        end
      end
      @prerendered_map.blit @screen, [@offset[0]*-TILE_WIDTH, @offset[1]*-TILE_HEIGHT]
    end

    #
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
          @connection.game.sprite_location_for_class(character.job)
        else
          #their guys
          @connection.game.sprite_location_for_class(character.job)
        end
      end
    end

    def draw_selecting_characters
      @connection.game.my_character_locations.each do |loc, char|
        #if this is the current location
        if @connection.game.my_character_locations[@current_selection_location][0] == loc
          #TODO draw GREEN
          draw_sprite 3,1,screen_location(*loc)
        else
          #TODO draw BLUE
          draw_sprite 1,3,screen_location(*loc)
        end


        #cx,cy = get_sprite_for_character(char)
        cx,cy = @connection.game.character_templates[char].sprite
        draw_sprite cx,cy,screen_location(*loc)
      end
    end

    def draw_shadow loc
      #draw_tile 5,9, loc
      draw_color_tile FOG_OF_WAR, screen_location(*loc), 50
    end

    #TODO rename to draw_characters
    def draw_units
      game = @connection.game
      #game.state.chars.each_pair do |key, val| 
      game.map.width.times do |x|
        game.map.height.times do |y|
          if on_screen? x,y
            if !game.shadows.lit?(x,y)
              #draw a shadow
              #draw_tile 5,9, screen_location(x,y)
              draw_shadow screen_location(x,y)
            else
              if character_to_draw?(x,y)
                current_character = game.state.character_at x,y
                cx,cy = get_sprite_for_character current_character 

                draw_color_tile (current_character.owner == @name ? FRIEND : FOE), screen_location(x,y), 100
                draw_sprite cx,cy,screen_location(x,y)
              end
            end
          end
        end
        if @state_change && @state_change.is_a?(StateChange::Movement)
          current_character = game.state.character_by_c_id @state_change.unit
          cx,cy = get_sprite_for_character current_character 
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

    def draw_panel
      if @connection.game.mode != @old_game_mode
        @panel = nil
      end
      @old_game_mode = @connection.game.mode
      if !@panel
        @panel = Surface.new([SCREEN_WIDTH, PANEL_HEIGHT])
        @panel.fill COLOR_BLACK
        case @connection.game.mode
        when :select_characters
          @text.render("Select your characters.", true, COLOR_WHITE).blit @panel, [0,0] 
        when :lobby
          @text.render("Waiting for other people to join.", true, COLOR_WHITE).blit @panel, [0,0] 
        when :in_progress
          if @connection.game.state.is_character_at?(*@cursor) && @connection.game.shadows.lit?(*@cursor)
            char = @connection.game.state.character_at(*@cursor)
            @text.render("Owner is: #{char.owner}, and id: #{char.c_id}.", true, COLOR_WHITE).blit @panel, [0,0]
            @text.render("Class is: #{char.job}.", true, COLOR_WHITE).blit @panel, [0, TEXT_SIZE]
            @text.render("HP #{char.health}/#{char.max_health}", true, COLOR_WHITE).blit @panel, [0, TEXT_SIZE*2]
          end
        end
      end
      @panel.blit(@screen,[0,TILES_HIGH*TILE_HEIGHT])
    end

    def draw_game
      @screen.fill [0,0,0]
      draw_map

      #TITLE
      case @connection.game.mode
      when :select_characters
        draw_selecting_characters
      when :in_progress
        #@text.render("Game is running.", true, [0,0,0]).blit @screen, [0,0]
        draw_units
        draw_pending_action
        #cursor
        draw_tile 0,9, [@cursor[0]-@offset[0], @cursor[1]-@offset[1]]
      end
      draw_panel
    end

    def draw_path
      if @path
        @path.each do |l|
          draw_sprite 11,9,screen_location(*l)
        end
      end
    end

    def draw_pending_action
      @pending_action.highlights.each do |l|
        #draw_transparent_tile 5,10,screen_location(*l)
        draw_color_tile [0,255,0], screen_location(*l), 50
      end if @pending_action
    end

    def load_image_from_sprite_sheet sx,sy, ss
      $LOGGER.info("Creating sprite for #{ss.inspect} at x:#{sx}, y#{sy}")
      rtn  = Surface.new [SPRITE_WIDTH, SPRITE_HEIGHT]
      ss.blit rtn, [0,0], [sx*SPRITE_WIDTH, sy*SPRITE_HEIGHT, SPRITE_WIDTH, SPRITE_HEIGHT]
      rtn = rtn.zoom SPRITE_STRETCH, false
      rtn.set_colorkey ss.colorkey
    end
    def draw_from_sprite_sheet sx, sy, location, target, ss
      x,y = location
      (@sprite_cache[[sx,sy,ss]] ||= load_image_from_sprite_sheet sx,sy,ss).blit target, [TILE_WIDTH*x,TILE_HEIGHT*y]
    end

    def draw_sprite sx,sy,location, target=@screen
      draw_from_sprite_sheet sx,sy,location,target,@sprite_sheet
    end
    def draw_tile sx,sy,location, target=@screen
      draw_from_sprite_sheet sx,sy,location,target,@dungeon
    end
    def draw_color_tile color, location, opacity=255, target=@screen
      x,y = location
      unless @color_cache[color]
        @color_cache[color] = Surface.new [TILE_WIDTH, TILE_HEIGHT]
        @color_cache[color].fill color
      end
      surf = @color_cache[color]
      surf.alpha = opacity
      surf.blit(target, [TILE_WIDTH*x, TILE_HEIGHT*y])
    end
    def draw_transparent_tile sx,sy,location
      x,y = location
      sur = (@sprite_cache[[sx,sy,@dungeon]] ||= load_image_from_sprite_sheet sx,sy, @dungeon)
      sur.alpha = 100
      sur.blit @screen, [TILE_WIDTH*x, TILE_HEIGHT*y]
    end


    #-------------------------------
    #        INPUT METHODS
    #-------------------------------

    def initialize_input
      @cursor = [0,0]
      @pending_action = nil

      @select_character = 0
      @current_selection_location = 0

      #shouldn't this just be... a hash?
      @actions = [InputAction.new(:a,Action::Attack), InputAction.new(:m, Action::Movement), InputAction.new(:w, Action::EndTurn), InputAction.new(:t, Action::Smokebomb), InputAction.new(:r, Action::TakeRoot)]
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

    def process_event ev
      case @connection.game.mode
      when :in_progress then process_in_progress_event(ev) and return
      when :select_characters then process_select_character_event(ev) and return
      end if @connection.game
    end

    def  process_select_character_event ev
      if ev.is_a? Events::KeyPressed
        case ev.key
        when :up 
          @connection.game.my_character_locations[@current_selection_location][1] += 1
          @connection.game.my_character_locations[@current_selection_location][1] = 0 if @connection.game.my_character_locations[@current_selection_location][1] >= @connection.game.character_templates.size
          return
        when :down 
          @connection.game.my_character_locations[@current_selection_location][1] -= 1
          @connection.game.my_character_locations[@current_selection_location][1] = @connection.game.character_templates.size-1 if @connection.game.my_character_locations[@current_selection_location][1] < 0
          return
        when :right 
          @current_selection_location += 1
          @current_selection_location -= @connection.game.my_character_locations.size if @current_selection_location >= @connection.game.my_character_locations.size
          return
        when :left 
          @current_selection_location -= 1
          @current_selection_location += @connection.game.my_character_locations.size if @current_selection_location < 0
          return
          #when :space then @connection.send_object(Message::ChooseCharacters.new([Character.new(@name, "soldier", [], [rand(15),rand(15)])])) and return
        when :space 
          @connection.send_object(Message::ChooseCharacters.new(@connection.game.my_character_locations.map do |loc,t| 
            Character.new(@name, @connection.game.character_templates[t].name, #@connection.game.character_templates[t].moves, loc) 
                          [],loc)
          end ))
        end
      end
    end

    #TODO this needs to be refactored like whoa
    #
    def process_in_progress_event ev 
      if ev.is_a? Events::KeyPressed
        @panel = nil
        #Whenever you do something on the keyboard, reset the @panel
        @cursor[1] += 1 if ev.key == :j
        @cursor[1] -= 1 if ev.key == :k
        @cursor[0] += 1 if ev.key == :l
        @cursor[0] -= 1 if ev.key == :h

        #find the action for the key we pressed
        input_action = @actions.find{|act| act.key == ev.key}
        input_action = nil if @connection.game.state.current_character.owner != @name
        # if it exists, and we're either at the primary action state of the game or this is
        # a secondary action, continue
        if input_action && (@connection.game.state.movable || input_action.secondary_action)
          #if we alaready pressed a different key, either do that if its instant, or pend
          #that action
          if !@pending_action.is_a?(input_action.klass)
            if input_action.klass.no_confirm
              @connection.send_object Message::Game.new(:action, input_action.klass.new(@connection.game))
            else
              @pending_action = input_action.klass.new @connection.game
            end
          elsif @pending_action.highlights.include? @cursor
            #else, if we're on a suitable square, do the action
            @connection.send_object Message::Game.new(:action,@pending_action.prep(@cursor, @connection.game))
            @pending_action = nil
          end
        end
      end
      normalize_cursor
    end
  end
end
