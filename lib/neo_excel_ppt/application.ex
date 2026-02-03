defmodule NeoExcelPPT.Application do
  @moduledoc """
  The NeoExcelPPT Application.

  Starts the supervision tree including:
  - Phoenix Endpoint
  - Skills Registry (manages all skill actors)
  - Event Store (event sourcing for replay)
  - PubSub for inter-skill communication
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Telemetry
      NeoExcelPPTWeb.Telemetry,
      # PubSub for skill communication
      {Phoenix.PubSub, name: NeoExcelPPT.PubSub},
      # Event Store for replay functionality
      NeoExcelPPT.Skills.EventStore,
      # Skills Registry - manages all skill actors
      NeoExcelPPT.Skills.Registry,
      # Finch HTTP client
      {Finch, name: NeoExcelPPT.Finch},
      # Phoenix Endpoint
      NeoExcelPPTWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: NeoExcelPPT.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    NeoExcelPPTWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
