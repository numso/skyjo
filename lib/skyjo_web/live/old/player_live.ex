defmodule SkyjoWeb.PlayerLive do
  use SkyjoWeb, :live_view

  @impl true
  def mount(params, session, socket) do
    IO.inspect(params: params, session: session)
    code = "abc123"
    if connected?(socket), do: Skyjo.Games.subscribe(code)
    msg = Skyjo.Games.get_game(code)
    {:ok, socket |> assign(msg: msg)}
  end

  @impl true
  def handle_event("update_message", %{"msg" => msg}, socket) do
    id = "need to get id"
    Skyjo.Games.set_game(id, msg)
    {:noreply, socket}
  end
end
