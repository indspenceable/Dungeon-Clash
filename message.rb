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
        $LOGGER.info "Got player named: <#{@name}>"
        connection.player.name = @name
        connection.try_join_game @name
        @info = nil
        # It will only set the connection's game if there is room to join it.
        if connection.game
          $LOGGER.info "Connection has joined game."
          #TODO - PlayerIndex so that playes are just stored in the game as names anyway
          @info = [connection.game.name, connection.game.players.collect{|p| p.name}, connection.game.map]
        else
          $LOGGER.debug "New connection was rejected from game."
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

    class Message
      def initialize action, args
        @action = action
        @args = args
      end
      def exec target
        target.send(@action, @args) 
      end
    end
    class Game
      def initialize action, args
        @action = action
        @args = args
      end
      def exec target
        target.game.send(@action, @args) 
      end
    end

    # IDEALLY, we can get by with just these two.

    class SelectCharacters
      def initialize plnames
        @names = plnames
      end
      def exec client
        client.game.select_characters @names
      end
    end

    class StartGame
      def initialize state
        @state = state
      end
      def exec client
        client.game.set_initial_state @state
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
        client.game.set_player_finalized @pname
      end
    end
    class ChooseCharacters
      def initialize characters
        @chars = characters
      end
      def exec connection
        #TODO
        #confirm that characters are valid?
        connection.game.set_player_finalized connection.player
      end
    end
  end
end 
