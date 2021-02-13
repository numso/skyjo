defmodule Skyjo.Games do
  use Agent

  @topic inspect(__MODULE__)

  def start_link(_) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def get_game(code) do
    Agent.get(__MODULE__, &Map.get(&1, code))
  end

  def set_game(game) do
    broadcast(game)
    Agent.update(__MODULE__, &Map.put(&1, game.code, game))
  end

  def subscribe(code) do
    Phoenix.PubSub.subscribe(Skyjo.PubSub, @topic <> code)
  end

  defp broadcast(game) do
    Phoenix.PubSub.broadcast(Skyjo.PubSub, @topic <> game.code, {:game_updated, game})
  end
end
