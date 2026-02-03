defmodule NeoExcelPPT.Skills.ComponentScalerSkill do
  @moduledoc """
  Skill for calculating component scaling metrics.

  Computes effort based on component counts, time per unit,
  and automation percentages.

  The scaling calculator uses:
  - Default Unit: 15 components = 1 day effort

  Input Channels:
  - Component counts from ProjectScopeSkill
  - Time per unit settings
  - Automation percentages

  Output Channels:
  - :scaling_summary - Full scaling breakdown
  - :total_base_days
  - :total_final_days
  """

  use NeoExcelPPT.Skills.Skill

  @default_unit 15  # 15 components = 1 day

  @impl true
  def name, do: :component_scaler

  @impl true
  def input_channels do
    [
      :simple_components,
      :medium_components,
      :complex_components,
      :simple_time_per_unit,
      :medium_time_per_unit,
      :complex_time_per_unit,
      :simple_auto_pct,
      :medium_auto_pct,
      :complex_auto_pct
    ]
  end

  @impl true
  def output_channels do
    [
      :scaling_summary,
      :total_base_days,
      :total_final_days,
      :total_units
    ]
  end

  @impl true
  def initial_state do
    %{
      simple_components: 825_000,
      medium_components: 16_500,
      complex_components: 33_000,
      simple_time_per_unit: 0.16,  # days per unit
      medium_time_per_unit: 2.16,
      complex_time_per_unit: 4.32,
      simple_auto_pct: 90,
      medium_auto_pct: 75,
      complex_auto_pct: 65
    }
  end

  @impl true
  def compute(inputs) do
    simple_comp = Map.get(inputs, :simple_components, 825_000)
    medium_comp = Map.get(inputs, :medium_components, 16_500)
    complex_comp = Map.get(inputs, :complex_components, 33_000)

    simple_time = Map.get(inputs, :simple_time_per_unit, 0.16)
    medium_time = Map.get(inputs, :medium_time_per_unit, 2.16)
    complex_time = Map.get(inputs, :complex_time_per_unit, 4.32)

    simple_auto = Map.get(inputs, :simple_auto_pct, 90)
    medium_auto = Map.get(inputs, :medium_auto_pct, 75)
    complex_auto = Map.get(inputs, :complex_auto_pct, 65)

    # Calculate units (component count / default unit)
    simple_units = simple_comp / @default_unit
    medium_units = medium_comp / @default_unit
    complex_units = complex_comp / @default_unit

    # Calculate base days (units * time per unit)
    simple_base = simple_units * simple_time
    medium_base = medium_units * medium_time
    complex_base = complex_units * complex_time

    # Calculate final days (accounting for automation)
    simple_final = simple_base * (1 - simple_auto / 100)
    medium_final = medium_base * (1 - medium_auto / 100)
    complex_final = complex_base * (1 - complex_auto / 100)

    total_units = simple_units + medium_units + complex_units
    total_base = simple_base + medium_base + complex_base
    total_final = simple_final + medium_final + complex_final

    avg_auto_pct = if total_base > 0 do
      ((total_base - total_final) / total_base * 100) |> Float.round(1)
    else
      0
    end

    %{
      scaling_summary: %{
        rows: [
          %{
            type: "Simple files",
            count: div(simple_comp, 15),
            avg_units: 15,
            total_units: simple_units,
            time_per_unit: simple_time,
            base_days: simple_base,
            auto_pct: simple_auto,
            final_days: simple_final
          },
          %{
            type: "Medium files",
            count: div(medium_comp, 150),
            avg_units: 150,
            total_units: medium_units,
            time_per_unit: medium_time,
            base_days: medium_base,
            auto_pct: medium_auto,
            final_days: medium_final
          },
          %{
            type: "Complex files",
            count: div(complex_comp, 300),
            avg_units: 300,
            total_units: complex_units,
            time_per_unit: complex_time,
            base_days: complex_base,
            auto_pct: complex_auto,
            final_days: complex_final
          }
        ],
        totals: %{
          total_units: total_units,
          total_base_days: total_base,
          avg_auto_pct: avg_auto_pct,
          total_final_days: total_final
        }
      },
      total_base_days: total_base,
      total_final_days: total_final,
      total_units: total_units
    }
  end
end
