defmodule Skyjo.Games do
  @topic inspect(__MODULE__)

  def create() do
    {:ok, pid} = DynamicSupervisor.start_child(__MODULE__, Skyjo.Game)
    GenServer.call(pid, :game)
  end

  def get_game(code) do
    Skyjo.Game.get_game(code)
  end

  def subscribe(code) do
    Phoenix.PubSub.subscribe(Skyjo.PubSub, @topic <> code)
  end

  def broadcast(code, msg) do
    Phoenix.PubSub.broadcast(Skyjo.PubSub, @topic <> code, msg)
  end
end
