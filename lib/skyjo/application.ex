defmodule Skyjo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: Skyjo.Games},
      # Start the Telemetry supervisor
      SkyjoWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Skyjo.PubSub},
      # Start the Endpoint (http/https)
      SkyjoWeb.Endpoint
      # Start a worker by calling: Skyjo.Worker.start_link(arg)
      # {Skyjo.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Skyjo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SkyjoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
