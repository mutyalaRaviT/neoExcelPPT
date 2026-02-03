defmodule NeoExcelPPT.Skills.EffortAggregatorSkill do
  @moduledoc """
  Skill for aggregating total effort across all activities.

  Computes:
  - Base Manual Days
  - Base Automation Days
  - Total Base Days
  - Team composition requirements

  Input Channels:
  - :activities_summary from ActivityCalculatorSkill
  - :scaling_summary from ComponentScalerSkill

  Output Channels:
  - :effort_breakdown
  - :team_composition
  """

  use NeoExcelPPT.Skills.Skill

  @impl true
  def name, do: :effort_aggregator

  @impl true
  def input_channels do
    [
      :total_base_days,
      :total_final_days,
      :activities_summary,
      :scaling_summary
    ]
  end

  @impl true
  def output_channels do
    [
      :effort_breakdown,
      :team_composition,
      :project_summary
    ]
  end

  @impl true
  def initial_state do
    %{
      total_base_days: 310_437,
      total_final_days: 503,
      auto_pct: 76.8
    }
  end

  @impl true
  def compute(inputs) do
    total_base = Map.get(inputs, :total_base_days, 310_437)
    total_final = Map.get(inputs, :total_final_days, 503)

    auto_days = total_base - total_final
    auto_pct = if total_base > 0, do: Float.round(auto_days / total_base * 100, 1), else: 0

    # Estimate team composition based on effort
    # Assuming 8 hours/day, 20 days/month
    work_days_per_person_month = 20
    estimated_months = 6  # Project duration assumption

    total_person_days = total_final
    persons_needed = total_person_days / (work_days_per_person_month * estimated_months)

    # Split between automation and testing teams
    automation_team = Float.ceil(persons_needed * 0.5) |> trunc()
    testing_team = Float.ceil(persons_needed * 0.5) |> trunc()

    %{
      effort_breakdown: %{
        base_manual_days: total_final,
        base_automation_days: auto_days,
        total_base_days: total_base,
        auto_pct: auto_pct
      },
      team_composition: %{
        automation_team: max(automation_team, 6),
        testing_team: max(testing_team, 6),
        total_resources: max(automation_team, 6) + max(testing_team, 6)
      },
      project_summary: %{
        total_effort_days: total_final,
        automation_savings: auto_days,
        efficiency_gain: "#{auto_pct}%"
      }
    }
  end
end
