defmodule NeoExcelPPT.Skills.ProjectScopeSkill do
  @moduledoc """
  Project Scope Skill - Manages file counts and component calculations.

  Pure Function: file_counts -> {total_files, component_breakdown}

  Input Channels:
  - :file_counts - %{simple: n, medium: n, complex: n}

  Output Channels:
  - :total_files - integer
  - :component_breakdown - %{simple: n, medium: n, complex: n, total: n}
  """

  use NeoExcelPPT.Skills.Skill

  # Component multipliers
  @simple_multiplier 15
  @medium_multiplier 150
  @complex_multiplier 300

  @impl true
  def skill_id, do: :project_scope

  @impl true
  def input_channels, do: [:file_counts, :project_type]

  @impl true
  def output_channels, do: [:total_files, :component_breakdown]

  @impl true
  def initial_state do
    %{
      simple_files: 55000,
      medium_files: 110,
      complex_files: 110,
      project_type: "ODI → IDMC",
      total_files: 55220,
      component_breakdown: %{
        simple: 825_000,
        medium: 16_500,
        complex: 33_000,
        total: 874_500
      }
    }
  end

  @impl true
  def compute(state, input) do
    case input.channel do
      :file_counts ->
        data = input.data
        simple = Map.get(data, :simple, state.simple_files)
        medium = Map.get(data, :medium, state.medium_files)
        complex = Map.get(data, :complex, state.complex_files)

        total_files = simple + medium + complex

        simple_components = simple * @simple_multiplier
        medium_components = medium * @medium_multiplier
        complex_components = complex * @complex_multiplier
        total_components = simple_components + medium_components + complex_components

        new_state = %{state |
          simple_files: simple,
          medium_files: medium,
          complex_files: complex,
          total_files: total_files,
          component_breakdown: %{
            simple: simple_components,
            medium: medium_components,
            complex: complex_components,
            total: total_components
          }
        }

        outputs = %{
          total_files: total_files,
          component_breakdown: new_state.component_breakdown
        }

        {new_state, outputs}

      :project_type ->
        new_state = %{state | project_type: input.data}
        {new_state, %{}}

      _ ->
        {state, %{}}
    end
  end
end
