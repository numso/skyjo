defmodule SkyjoWeb.ReceiverLive do
  use SkyjoWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_event("start", %{"code" => code}, socket) do
    IO.inspect("Start a game for #{code}")
    {:noreply, socket}
  end
end
