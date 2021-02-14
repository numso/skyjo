defmodule SkyjoWeb.PageLive do
  use SkyjoWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(code: "ABC123")}
  end

  @impl true
  def handle_event("join", %{"code" => code}, socket) do
    IO.inspect("Attempt to join #{code}")
    {:noreply, socket}
  end

  @impl true
  def handle_event("create", _, socket) do
    IO.inspect("Create and join a new game")
    {:noreply, socket}
  end
end
