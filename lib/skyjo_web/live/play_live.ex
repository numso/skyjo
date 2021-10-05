defmodule SkyjoWeb.PlayLive do
  use SkyjoWeb, :live_view

  alias Skyjo.{Game, Games}
  alias SkyjoWeb.Card

  @impl true
  def mount(%{"code" => code, "player" => player}, _session, socket) do
    if connected?(socket), do: Games.subscribe(code)

    case Games.get_game(code) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "No game found for that Join Code")
         |> push_redirect(to: "/")}

      game ->
        case socket |> assign(pid: player) |> assign_defaults(game) do
          %{assigns: %{player: nil}} ->
            {:ok,
             socket
             |> put_flash(:error, "Invalid player code")
             |> push_redirect(to: "/")}

          socket ->
            {:ok, socket}
        end
    end
  end

  @impl true
  def mount(_, _session, socket) do
    {:ok,
     socket
     |> put_flash(:error, "Missing Game or Player Code")
     |> push_redirect(to: "/")}
  end

  @impl true
  def handle_event("noop", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_name", %{"name" => name}, socket) do
    send_game_message(socket, {:rename, name})
  end

  @impl true
  def handle_event("start", _, socket) do
    send_game_message(socket, :start)
  end

  @impl true
  def handle_event("leave", _, socket) do
    send_game_message(socket, {:kick, socket.assigns.pid})
  end

  @impl true
  def handle_event("kick", %{"id" => pid}, socket) do
    send_game_message(socket, {:kick, pid})
  end

  @impl true
  def handle_event("ready", _, socket) do
    send_game_message(socket, :ready)
  end

  @impl true
  def handle_event("reveal", %{"i" => i}, socket) do
    send_game_message(socket, {:reveal, String.to_integer(i)})
  end

  @impl true
  def handle_event("drop", %{"i" => i}, socket) do
    send_game_message(socket, {:drop, String.to_integer(i)})
  end

  @impl true
  def handle_event("undo", _, socket) do
    send_game_message(socket, :undo)
  end

  @impl true
  def handle_event("take_discard", _, socket) do
    send_game_message(socket, :take_discard)
  end

  @impl true
  def handle_event("take_deck", _, socket) do
    send_game_message(socket, :take_deck)
  end

  @impl true
  def handle_event("discard", _, socket) do
    send_game_message(socket, :discard)
  end

  @impl true
  def handle_info({:game_updated, game}, socket) do
    {:noreply, assign_defaults(socket, game)}
  end

  @impl true
  def handle_info({:player_kicked, pid}, %{assigns: %{pid: pid}} = socket) do
    {:noreply, push_redirect(socket, to: "/")}
  end

  @impl true
  def handle_info(_, socket) do
    {:noreply, socket}
  end

  defp send_game_message(%{assigns: %{game: game, pid: pid}} = socket, msg) do
    Game.transition(game, pid, msg)
    {:noreply, socket}
  end

  defp assign_defaults(socket, game) do
    socket
    |> assign(game: game)
    |> assign(player: Enum.find(game.players, &(&1.code == socket.assigns.pid)))
  end

  defp cast_app_id() do
    Application.get_env(:skyjo, :chromecast) |> Keyword.get(:app_id)
  end

  defp game_can_start(game) do
    # TODO:: we shouldn't allow a game to start if there's less than 2 people. This isn't respected after the :lobby state
    game.players |> Enum.filter(& &1.active?) |> length() >= 2
  end

  defp is_host(game, player) do
    case game.players
         |> Enum.filter(& &1.active?)
         |> Enum.reverse()
         |> Enum.find_index(&(&1.code == player.code)) do
      0 -> true
      _ -> false
    end
  end

  def deck_state(game, player) do
    case {my_turn?(game, player), game.state} do
      {true, :draw} -> "draw"
      {true, :discard} -> "discard"
      {true, :reveal} -> "reveal"
      _ -> "none"
    end
  end

  def instruction(game, player) do
    case deck_state(game, player) do
      "none" -> ""
      "draw" -> "Pick a card from the deck or discard pile"
      "discard" -> "Tap and drag your card to place it"
      "reveal" -> "Tap a spot on your board to reveal it"
    end
  end

  def my_turn?(%{cur_player: pid}, %{code: pid}), do: true
  def my_turn?(_, _), do: false
end
