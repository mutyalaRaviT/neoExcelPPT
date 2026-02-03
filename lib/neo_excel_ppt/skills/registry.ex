defmodule NeoExcelPPT.Skills.Registry do
  @moduledoc """
  Skills Registry - manages the lifecycle of all skill actors.

  Responsibilities:
  - Start and stop skill processes
  - Track all running skills
  - Provide lookup by skill name
  - Initialize default skills for a project
  - Handle skill failures and restarts

  ## Architecture

  The Registry is a supervisor that manages skill processes.
  Each skill is a GenServer that:
  - Subscribes to input channels
  - Computes outputs from inputs
  - Publishes to output channels
  - Records events to EventStore

  ## Usage

      # Start a skill
      Registry.start_skill(ProjectScopeSkill)

      # Get all running skills
      Registry.list_skills()

      # Stop a skill
      Registry.stop_skill(:project_scope)
  """

  use Supervisor

  alias NeoExcelPPT.Skills

  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl Supervisor
  def init(_opts) do
    # Start the process registry for skill lookup
    children = [
      {Registry, keys: :unique, name: Skills.ProcessRegistry}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc "Start a skill by its module"
  def start_skill(skill_module) do
    spec = %{
      id: skill_module.name(),
      start: {skill_module, :start_link, [[]]},
      restart: :transient
    }

    Supervisor.start_child(__MODULE__, spec)
  end

  @doc "Stop a skill by name"
  def stop_skill(skill_name) do
    Supervisor.terminate_child(__MODULE__, skill_name)
    Supervisor.delete_child(__MODULE__, skill_name)
  end

  @doc "List all running skills"
  def list_skills do
    __MODULE__
    |> Supervisor.which_children()
    |> Enum.filter(fn {id, _, _, _} -> id != Registry end)
    |> Enum.map(fn {id, pid, _, _} -> {id, pid} end)
  end

  @doc "Get a skill process by name"
  def get_skill(skill_name) do
    case Registry.lookup(Skills.ProcessRegistry, skill_name) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  @doc "Check if a skill is running"
  def skill_running?(skill_name) do
    case get_skill(skill_name) do
      {:ok, _} -> true
      _ -> false
    end
  end

  @doc "Initialize all default project skills"
  def init_project_skills do
    skills = [
      Skills.ProjectScopeSkill,
      Skills.ComponentScalerSkill,
      Skills.ActivityCalculatorSkill,
      Skills.EffortAggregatorSkill,
      Skills.BufferCalculatorSkill
    ]

    Enum.each(skills, &start_skill/1)
  end

  @doc "Stop all skills"
  def stop_all_skills do
    list_skills()
    |> Enum.each(fn {name, _pid} -> stop_skill(name) end)
  end
end
