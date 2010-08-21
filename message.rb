module DCGame
  module Message
    # A dialog is an arbitrary length backand forth
    class Dialog
      def initialize states
        @states = states
        @state = 0
      end
      def exec otherside
        #method(@states[@state]).call otherside
        send @states[@state], otherside
        otherside.send_object self if (@state += 1) < @states.length
      end
    end

    class Query < Dialog
      def initialize
        super [:respond, :accept]
      end
    end

    ###################################
    #           Dialogs               #
    ###################################

    class Handshake < Dialog
      def initialize
        super [:ask_name, :ask_join_game, :accept, :start]
      end
      def ask_name client
        @name = client.name
      end
      def ask_join_game connection
        $LOGGER.info "Got player name <#{@name}>"
        connection.player.name = @name
        @info = nil
        $LOGGER.info "Their game is #{connection.game}"
        if connection.game
          $LOGGER.info "They have a game."
          @info = [connection.game.name, connection.game.players.collect{|p| p.name}, connection.game.settings]
        end
      end
      def accept client
        #client.game_list = @game_list
        client.set_game *@info if @info
        client.fail unless @info
      end
      def start connection
        connection.game.add_player connection.player if @info
      end
    end

    ###################################
    #           Outliers              #
    ###################################

    class MoveCurrentCharacter
      def initialize to_location
        
      end
      def exec connection
      end
    end

    class SelectCharacters
      def initialize plnames
        @names = plnames
      end
      def exec client
        client.game.select_characters @names
      end
    end

    class StartGame
      def initialize characters, first
        @characters = characters
        @first = first
      end
      def exec client
        client.game.set_initial_state @characters, @first
        puts "first is #{@first}"
        client.game.start
      end
    end

    # TODO this should take a c_id as the argument, rather than
    # the loation of the character
    class DeclareCharacterToMove
      def initialize loc
        @loc = loc
      end
      def exec client
        client.current_character @loc
      end
    end

    class PlayerHasJoined
      def initialize name
        @name = name
      end
      def exec client
        client.game.add_player @name
      end
    end

    class PlayerLeft
      def initialize pname
        @pname = pname
      end
      def exec client
        client.game.players.delete @pname
        client.game.return_to_lobby
      end
    end

    class PlayerFinalized
      def initialize playername
        @pname = playername
      end
      def exec client
        client.game.finalize_player @pname
      end
    end
    class ChooseCharacters
      def initialize characters
        @chars = characters
      end
      def exec connection
        #TODO
        #confirm that characters are valid?
        connection.game.finalize_player connection.player if !connection.game.nil? && connection.game.started?
      end
    end
  end
end 
