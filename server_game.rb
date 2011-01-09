require './game'
module DCGame 
  module Server
    class Game < Games::Base
      def initialize name
        super(name, Board.new(15,15))
      end

      # Inform the game that a player has joined.
      #TODO Make this work with a string, using PlayerIndex
      def add_player player
        super
        if full?
          begin_character_selection
        else 
          $LOGGER.info "Informing those connected that #{player} has joined."
          @players.reject{|p| p==player}.each do |p|
            p.owner.send_object Message::Message.new(:add_player, player.name)
          end
        end
      end

      # All the players have joined, so we've started character selection.
      # TODO make this work with a string, using PlayerIndex
      def begin_character_selection
        $LOGGER.info "All players have joined, so game is moving into character selection."
        
        starting_locations = [] 
        (5*players.size).times do
          loc = [rand(@map.width), rand(@map.height)]
          loc = [rand(@map.width), rand(@map.height)] until passable? loc
          starting_locations << loc
        end

        @mode = :select_characters
        players.each do |p|
          @finalized_players.set_player_finalized p.name, false
          #p.owner.send_object Message::SelectCharacters.new players.reject{ |pl| p==pl}.collect{ |pl| pl.name}
          # OK at this point, we need to get the locations for this mode
          # Select 5 locations at random

          my_locations = starting_locations.first(5).map{|e| [e,0]}
          starting_locations = starting_locations.drop(5)

          p.owner.send_object Message::Game.new(:begin_character_selection, [players.reject{ |pl| p==pl}.collect{ |pl| pl.name}, my_locations] )
        end
      end

      # Tell the game that this player is finished choosing their character.
      def set_player_finalized player, chars

        @finalized_players.set_player_finalized player.name, true

        #5.times do
        #  loc = [rand(@map.width), rand(@map.height)]
        #  loc = [rand(@map.width), rand(@map.height)] until passable? loc
        #  @state.characters << (Character.new player.name, "soldier", [], loc)
        #end
        chars.each do |c|
          @state.characters << c
        end

        if @finalized_players.all_players_finalized?

          $LOGGER.info "All Players are finalized, so the game is starting."
          #@state.set_current_character_by_c_id @state.characters[rand @state.characters.length].c_id
          @state.characters.size.downto(1) { |n| @state.characters.push @state.characters.delete_at(rand(n)) }

          #ok, now make sure each character has a unique c_id
          @state.characters.size.times do |n|
            @state.characters[n].fatigue = 0
            @state.characters[n].tie_fatigue = n
            @state.characters[n].set_c_id n
          end

          @state.initialize_current_character!
          @state.choose_next_character_to_move!

          players.each do |p|
            p.owner.send_object Message::StartGame.new @state
          end
        else
          $LOGGER.debug "Sending out finalized_player alert."
          players.each do |p|
            p.owner.send_object Message::PlayerFinalized.new player.name
          end
        end
      end

      # For whatever reason, this game must return to lobby and restart.
      def return_to_lobby 
        $LOGGER.debug "Game is returning to lobby."
        @mode = :lobby
        @finalized_players.clear_players
        reset_variables
      end

      # Player has left the game.
      def remove_player p
        $LOGGER.debug "Player: #{p.name} has left the game."
        players.delete p
        players.each do |player|
          player.owner.send_object Message::PlayerLeft.new p.name
        end
        return_to_lobby
      end

      # run the action,to get the statechanges and activate them, and then do
      # any ensuing state changes
      # then send those results to clients.
      def action act
        state_changes = act.enact self  

        state_changes << StateChange::TireCurrentCharacter.new if act.class.tires_character
        state_changes << StateChange::ChooseNextCharacter.new if act.class.ends_turn 

        state_changes.each do |sc|
          sc.activate @state
        end
        ensuing_sc = ensuing_state_changes
        ensuing_sc.each do |sc|
          sc.activate @state
        end
        state_changes += ensuing_sc
        @players.each do |p|
          p.owner.send_object Message::Game.new(:accept_state_changes, state_changes)
        end
      end

      # Process the state and see what side effects the actions had
      # that, is things like timers, traps, and PEOPLE DIEING
      def ensuing_state_changes
        state_changes = Array.new
        begin
          @state.characters.each do |c|
            if c.health < 0
              state_changes << StateChange::Death.new(c.c_id)
            end
          end
        end
        state_changes 
      end

      def cost_per_move character; 1 end
    end
  end
end
