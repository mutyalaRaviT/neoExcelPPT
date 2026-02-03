defmodule NeoExcelPPT.Skills.EffortAggregatorSkill do
  @moduledoc """
  Effort Aggregator Skill - Combines all effort sources into totals.

  Pure Function: (component_effort, activity_effort) -> total_effort

  Input Channels:
  - :component_effort - From ComponentCalculator
  - :activity_effort - From ActivityCalculator

  Output Channels:
  - :total_days - Combined effort totals
  """

  use NeoExcelPPT.Skills.Skill

  @impl true
  def skill_id, do: :effort_aggregator

  @impl true
  def input_channels, do: [:component_effort, :activity_effort, :components]

  @impl true
  def output_channels, do: [:total_days]

  @impl true
  def initial_state do
    %{
      manual_days: 62.8,
      automation_days: 193.7,
      total_base_days: 256.5,
      component_effort: nil,
      activity_effort: nil,
      team: %{
        automation: 6,
        testing: 6,
        total: 12
      }
    }
  end

  @impl true
  def compute(state, input) do
    case input.channel do
      :component_effort ->
        effort = input.data
        new_state = %{state | component_effort: effort}
        recalculate_totals(new_state)

      :activity_effort ->
        effort = input.data
        new_state = %{state | activity_effort: effort}
        recalculate_totals(new_state)

      :components ->
        # Direct component breakdown update
        {state, %{}}

      _ ->
        {state, %{}}
    end
  end

  defp recalculate_totals(state) do
    # Calculate total from component and activity effort
    component_days = case state.component_effort do
      %{totals: %{final_days: days}} -> days
      _ -> 0
    end

    activity_days = case state.activity_effort do
      %{totals: %{final_days: days}} -> days
      _ -> 19.8  # Default from activities
    end

    total_final = component_days + activity_days
    total_base = total_final * 4  # Rough estimate

    auto_pct = if total_base > 0, do: (1 - total_final / total_base) * 100, else: 0

    new_state = %{state |
      manual_days: Float.round(total_final, 1),
      automation_days: Float.round(total_base - total_final, 1),
      total_base_days: Float.round(total_base, 1)
    }

    outputs = %{
      total_days: %{
        manual_days: new_state.manual_days,
        automation_days: new_state.automation_days,
        total_base_days: new_state.total_base_days,
        auto_pct: Float.round(auto_pct, 1),
        team: new_state.team
      }
    }

    {new_state, outputs}
  end
end
