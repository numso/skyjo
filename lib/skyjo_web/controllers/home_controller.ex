defmodule SkyjoWeb.HomeController do
  use SkyjoWeb, :controller

  alias Skyjo.{Game, Games}

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def create(conn, _params) do
    %Game{players: [player]} = game = Games.create()
    conn |> redirect(to: "/play/#{game.code}?player=#{player.code}")
  end

  def join(conn, %{"code" => code}) do
    code = String.upcase(code)

    case Game.join(code) do
      {:ok, {player, game}} ->
        conn |> redirect(to: "/play/#{game.code}?player=#{player.code}")

      {:error, :code_missing} ->
        conn |> put_flash(:error, "Join Code is required") |> redirect(to: "/")

      {:error, :game_missing} ->
        conn |> put_flash(:error, "No game found for that Join Code") |> redirect(to: "/")

      {:error, :game_in_progress} ->
        conn |> put_flash(:error, "Game is in progress") |> redirect(to: "/")

      {:error, :full_game} ->
        conn |> put_flash(:error, "Game is full") |> redirect(to: "/")
    end
  end

  def join(conn, _) do
    conn |> put_flash(:error, "Join Code is required") |> redirect(to: "/")
  end
end
