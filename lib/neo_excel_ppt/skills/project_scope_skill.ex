defmodule NeoExcelPPT.Skills.ProjectScopeSkill do
  @moduledoc """
  Skill for calculating project scope metrics.

  Computes:
  - Total files count
  - Component breakdown (simple, medium, complex)
  - Total components

  Input Channels:
  - :simple_files_count - Number of simple files (default 55000)
  - :medium_files_count - Number of medium files (default 110)
  - :complex_files_count - Number of complex files (default 110)
  - :simple_components_per_file - Components per simple file (default 15)
  - :medium_components_per_file - Components per medium file (default 150)
  - :complex_components_per_file - Components per complex file (default 300)

  Output Channels:
  - :total_files
  - :simple_components
  - :medium_components
  - :complex_components
  - :total_components
  """

  use NeoExcelPPT.Skills.Skill

  @impl true
  def name, do: :project_scope

  @impl true
  def input_channels do
    [
      :simple_files_count,
      :medium_files_count,
      :complex_files_count,
      :simple_components_per_file,
      :medium_components_per_file,
      :complex_components_per_file,
      :simple_auto_pct,
      :medium_auto_pct,
      :complex_auto_pct
    ]
  end

  @impl true
  def output_channels do
    [
      :total_files,
      :simple_components,
      :medium_components,
      :complex_components,
      :total_components,
      :project_scope_summary
    ]
  end

  @impl true
  def initial_state do
    %{
      simple_files_count: 55_000,
      medium_files_count: 110,
      complex_files_count: 110,
      simple_components_per_file: 15,
      medium_components_per_file: 150,
      complex_components_per_file: 300,
      simple_auto_pct: 90,
      medium_auto_pct: 75,
      complex_auto_pct: 65
    }
  end

  @impl true
  def compute(inputs) do
    simple_count = Map.get(inputs, :simple_files_count, 55_000)
    medium_count = Map.get(inputs, :medium_files_count, 110)
    complex_count = Map.get(inputs, :complex_files_count, 110)

    simple_per = Map.get(inputs, :simple_components_per_file, 15)
    medium_per = Map.get(inputs, :medium_components_per_file, 150)
    complex_per = Map.get(inputs, :complex_components_per_file, 300)

    simple_auto = Map.get(inputs, :simple_auto_pct, 90)
    medium_auto = Map.get(inputs, :medium_auto_pct, 75)
    complex_auto = Map.get(inputs, :complex_auto_pct, 65)

    simple_components = simple_count * simple_per
    medium_components = medium_count * medium_per
    complex_components = complex_count * complex_per
    total_components = simple_components + medium_components + complex_components
    total_files = simple_count + medium_count + complex_count

    %{
      total_files: total_files,
      simple_components: simple_components,
      medium_components: medium_components,
      complex_components: complex_components,
      total_components: total_components,
      project_scope_summary: %{
        total_files: total_files,
        project_type: "ODI → IDMC",
        breakdown: [
          %{
            type: :simple,
            files: simple_count,
            components_per: simple_per,
            total_components: simple_components,
            auto_pct: simple_auto,
            label: "Basic transformations"
          },
          %{
            type: :medium,
            files: medium_count,
            components_per: medium_per,
            total_components: medium_components,
            auto_pct: medium_auto,
            label: "Moderate complexity"
          },
          %{
            type: :complex,
            files: complex_count,
            components_per: complex_per,
            total_components: complex_components,
            auto_pct: complex_auto,
            label: "Advanced processing"
          }
        ]
      }
    }
  end
end
