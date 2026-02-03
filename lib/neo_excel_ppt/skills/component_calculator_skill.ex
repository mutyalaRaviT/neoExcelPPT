defmodule NeoExcelPPT.Skills.ComponentCalculatorSkill do
  @moduledoc """
  Component Calculator Skill - Calculates scaled effort from component counts.

  Pure Function: (component_counts, time_per_unit) -> scaled_effort

  Input Channels:
  - :breakdown - Component counts from ProjectScope
  - :time_per_unit - Days per unit configuration

  Output Channels:
  - :scaled_effort - %{base_days: n, final_days: n, auto_percentage: n}
  """

  use NeoExcelPPT.Skills.Skill

  # Default unit = 15 components = 1 day
  @components_per_day 15

  @impl true
  def skill_id, do: :component_calculator

  @impl true
  def input_channels, do: [:breakdown, :time_per_unit, :auto_percentage]

  @impl true
  def output_channels, do: [:scaled_effort]

  @impl true
  def initial_state do
    %{
      components: %{
        simple: %{count: 55000, avg_units: 15, time_per_unit: 0.16, auto_pct: 90},
        medium: %{count: 110, avg_units: 150, time_per_unit: 2.16, auto_pct: 75},
        complex: %{count: 110, avg_units: 300, time_per_unit: 4.32, auto_pct: 65}
      },
      scaled_effort: %{
        simple: %{total_units: 825_000, base_days: 132_000, final_days: 13_200},
        medium: %{total_units: 16_500, base_days: 35_640, final_days: 8_910},
        complex: %{total_units: 33_000, base_days: 142_560, final_days: 49_896}
      },
      totals: %{
        total_units: 874_500,
        base_days: 310_200,
        final_days: 72_006,
        avg_auto_pct: 76.8
      }
    }
  end

  @impl true
  def compute(state, input) do
    case input.channel do
      :breakdown ->
        # Recalculate based on new component breakdown
        breakdown = input.data

        simple_units = breakdown.simple
        medium_units = breakdown.medium
        complex_units = breakdown.complex

        # Get current config
        simple_cfg = state.components.simple
        medium_cfg = state.components.medium
        complex_cfg = state.components.complex

        # Calculate days
        simple_base = simple_units * simple_cfg.time_per_unit / @components_per_day
        medium_base = medium_units * medium_cfg.time_per_unit / @components_per_day
        complex_base = complex_units * complex_cfg.time_per_unit / @components_per_day

        simple_final = simple_base * (1 - simple_cfg.auto_pct / 100)
        medium_final = medium_base * (1 - medium_cfg.auto_pct / 100)
        complex_final = complex_base * (1 - complex_cfg.auto_pct / 100)

        scaled_effort = %{
          simple: %{total_units: simple_units, base_days: round(simple_base), final_days: round(simple_final)},
          medium: %{total_units: medium_units, base_days: round(medium_base), final_days: round(medium_final)},
          complex: %{total_units: complex_units, base_days: round(complex_base), final_days: round(complex_final)}
        }

        total_units = simple_units + medium_units + complex_units
        total_base = simple_base + medium_base + complex_base
        total_final = simple_final + medium_final + complex_final
        avg_auto = if total_base > 0, do: (1 - total_final / total_base) * 100, else: 0

        totals = %{
          total_units: total_units,
          base_days: round(total_base),
          final_days: round(total_final),
          avg_auto_pct: Float.round(avg_auto, 1)
        }

        new_state = %{state | scaled_effort: scaled_effort, totals: totals}

        outputs = %{
          scaled_effort: %{
            by_type: scaled_effort,
            totals: totals
          }
        }

        {new_state, outputs}

      :auto_percentage ->
        # Update automation percentage for a component type
        %{type: type, percentage: pct} = input.data
        components = Map.update!(state.components, type, fn cfg ->
          %{cfg | auto_pct: pct}
        end)
        new_state = %{state | components: components}
        {new_state, %{}}

      _ ->
        {state, %{}}
    end
  end
end
