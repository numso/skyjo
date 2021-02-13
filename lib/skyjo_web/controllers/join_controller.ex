defmodule SkyjoWeb.JoinController do
  use SkyjoWeb, :controller

  alias Skyjo.Game

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
end
