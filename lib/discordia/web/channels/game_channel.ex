defmodule Discordia.Web.GameChannel do
  use Phoenix.Channel

  alias Discordia.Web.Presence
  alias Discordia.{Game, GameServer, Player}

  def join("room:" <> room_name, _, socket) do
    send(self(), :after_join)
    {:ok, assign(socket, :room, room_name)}
  end

  def terminate(message, socket) do
    Game.stop(socket.assigns.room)
    broadcast!(socket, "game_stopped", %{})
    message
  end

  def handle_info(:after_join, socket) do
    Presence.track(socket, socket.assigns.username, %{
      online_at: :os.system_time(:milli_seconds)
    })
    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  def handle_in("start_game", %{"room" => room, "players" => players}, socket) do
    Game.start(room, players)
    broadcast!(socket, "game_started", game_info(socket))
    {:noreply, socket}
  end

  def handle_in("player_info", _, socket) do
    game = socket.assigns.room
    player = socket.assigns.username
    payload = %{
      cards: Player.cards(game, player)
    }
    {:reply, {:ok, payload}, socket}
  end

  def handle_in("play_card", card, socket) do
    game = socket.assigns.room
    player = socket.assigns.username

    card = for {k, v} <- card, into: %{} do
      {String.to_atom(k), v}
    end

    Game.play(game, player, card)
    broadcast!(socket, "game_info", game_info(socket))

    payload = %{
      cards: Player.cards(game, player)
    }
    {:reply, {:ok, payload}, socket}
  end

  defp game_info(socket) do
    game = socket.assigns.room

    %{
      current_player: GameServer.current_player(game),
      current_card: GameServer.current_card(game)
    }
  end
end
