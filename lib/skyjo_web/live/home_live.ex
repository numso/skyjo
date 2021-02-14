defmodule SkyjoWeb.HomeLive do
  use SkyjoWeb, :live_view

  alias Skyjo.Game

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_event("create", _, socket) do
    {player, game} = Game.create()
    {:noreply, socket |> push_redirect(to: "/play/#{game.code}?player=#{player.code}")}
  end

  @impl true
  def handle_event("join", %{"code" => code}, socket) do
    code = String.upcase(code)

    case Game.join(code) do
      {:ok, {player, game}} ->
        {:noreply, socket |> push_redirect(to: "/play/#{game.code}?player=#{player.code}")}

      {:error, :code_missing} ->
        {:noreply, socket |> put_flash(:error, "Join Code is required")}

      {:error, :game_missing} ->
        {:noreply, socket |> put_flash(:error, "No game found for that Join Code")}

      {:error, :game_in_progress} ->
        {:noreply, socket |> put_flash(:error, "Game is in progress")}

      {:error, :full_game} ->
        {:noreply, socket |> put_flash(:error, "Game is full")}
    end
  end

  def card_style(i) do
    degrees = 360 / 15 * (i + 2)
    radians = degrees / 180 * :math.pi()
    x = :math.cos(radians)
    y = :math.sin(radians)
    "top:#{250 + x * -150}px;left:#{y * 130 - 55}px;transform:rotate(#{degrees}deg);"
  end
end
