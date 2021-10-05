defmodule SkyjoWeb.SpectateLive do
  use SkyjoWeb, :live_view

  alias Skyjo.Games
  alias SkyjoWeb.Card

  @impl true
  def mount(params, _session, socket) do
    {:ok, setup_game(params, socket)}
  end

  defp setup_game(%{"code" => code}, socket) do
    case Games.get_game(code) do
      nil ->
        socket
        |> put_flash(:error, "No game found for that Join Code")
        |> push_redirect(to: "/")

      game ->
        if connected?(socket), do: Games.subscribe(code)
        assign(socket, game: game)
    end
  end

  defp setup_game(_, socket) do
    assign(socket, game: %{code: nil})
  end

  @impl true
  def handle_event("start", params, socket) do
    {:noreply, setup_game(params, socket)}
  end

  @impl true
  def handle_event(_, _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:game_updated, game}, socket) do
    {:noreply, assign(socket, game: game)}
  end

  @impl true
  def handle_info(_, socket) do
    {:noreply, socket}
  end

  defp rows(game) do
    players = Enum.filter(game.players, & &1.active?)

    if length(players) <= 3 do
      [Enum.reverse(players)]
    else
      mid = (length(players) / 2) |> :math.floor() |> trunc()
      {a, b} = Enum.split(players, mid)
      [Enum.reverse(b), a]
    end
  end

  defp score_class({_, :doubled}), do: "doubled"
  defp score_class({_, :first}), do: "first"
  defp score_class(_), do: ""

  defp player_class(%{cur_player: pid}, %{code: pid}), do: "current"
  defp player_class(%{out_player: pid}, %{code: pid}), do: "out"
  defp player_class(_, _), do: ""
end
