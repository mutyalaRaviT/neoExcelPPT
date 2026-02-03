defmodule NeoExcelPPT.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      NeoExcelPPTWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: NeoExcelPPT.PubSub},
      # Start the Skill Registry
      NeoExcelPPT.Skills.Registry,
      # Start the History Tracker (The Tape)
      NeoExcelPPT.Skills.HistoryTracker,
      # Start the Skill Manager (Communication Orchestrator)
      NeoExcelPPT.Skills.SkillManager,
      # Start the Endpoint (http/https)
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
