defmodule NeoExcelPPT.Skills.Registry do
  @moduledoc """
  Process Registry for Skills.

  Uses Elixir's built-in Registry to provide:
  - Unique process naming for skills
  - Fast skill lookup by skill_id
  - Automatic cleanup on skill termination

  ## Usage

  Skills register themselves using via_tuple:

      {:via, Registry, {NeoExcelPPT.Skills.Registry, :my_skill}}
  """

  def child_spec(_opts) do
    Registry.child_spec(keys: :unique, name: __MODULE__)
  end

  @doc "Lookup a skill process by its skill_id"
  def lookup(skill_id) do
    case Registry.lookup(__MODULE__, skill_id) do
      [{pid, _value}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  @doc "Check if a skill is registered"
  def registered?(skill_id) do
    case lookup(skill_id) do
      {:ok, _} -> true
      _ -> false
    end
  end

  @doc "Get all registered skill IDs"
  def all_skills do
    Registry.select(__MODULE__, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  @doc "Count registered skills"
  def count do
    Registry.count(__MODULE__)
  end
end
