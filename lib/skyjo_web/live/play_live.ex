defmodule SkyjoWeb.PlayLive do
  use SkyjoWeb, :live_view

  alias Skyjo.{Game, Games}

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
    Game.transition(socket.assigns.game, {socket.assigns.pid, :rename, name})
    {:noreply, socket}
  end

  @impl true
  def handle_event("start", _, socket) do
    Game.transition(socket.assigns.game, nil)
    {:noreply, socket}
  end

  def handle_event("ready", _, socket) do
    Game.transition(socket.assigns.game, {socket.assigns.pid, :ready})
    {:noreply, socket}
  end

  @impl true
  def handle_event("reveal", %{"i" => i}, socket) do
    Game.transition(socket.assigns.game, {socket.assigns.pid, :reveal, String.to_integer(i)})
    {:noreply, socket}
  end

  @impl true
  def handle_event("take_discard", _, socket) do
    Game.transition(socket.assigns.game, {socket.assigns.pid, :take_discard})
    {:noreply, socket}
  end

  @impl true
  def handle_event("take_deck", _, socket) do
    Game.transition(socket.assigns.game, {socket.assigns.pid, :take_deck})
    {:noreply, socket}
  end

  @impl true
  def handle_event("discard", _, socket) do
    Game.transition(socket.assigns.game, {socket.assigns.pid, :discard})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:game_updated, game}, socket) do
    {:noreply, socket |> assign_defaults(game)}
  end

  defp assign_defaults(socket, game) do
    socket
    |> assign(game: game)
    |> assign(player: Enum.find(game.players, &(&1.code == socket.assigns.pid)))
  end
end
