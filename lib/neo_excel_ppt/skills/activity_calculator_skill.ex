defmodule NeoExcelPPT.Skills.ActivityCalculatorSkill do
  @moduledoc """
  Activity Calculator Skill - Manages activities and team assignments.

  Pure Function: (activity_updates, team_assignments) -> activity_totals

  Input Channels:
  - :activity_update - Update to a specific activity
  - :team_assignment - Toggle team member assignment

  Output Channels:
  - :activity_totals - Summary of all activities
  """

  use NeoExcelPPT.Skills.Skill

  @impl true
  def skill_id, do: :activity_calculator

  @impl true
  def input_channels, do: [:activity_update, :team_assignment]

  @impl true
  def output_channels, do: [:activity_totals]

  @impl true
  def initial_state do
    %{
      activities: default_activities(),
      team_members: ["SB", "CG", "S2P"],
      totals: %{
        base_days: 82.5,
        final_days: 19.8,
        avg_auto_pct: 76
      }
    }
  end

  @impl true
  def compute(state, input) do
    case input.channel do
      :activity_update ->
        %{id: activity_id, field: field, value: value} = input.data

        activities = update_activity(state.activities, activity_id, field, value)
        totals = calculate_totals(activities)

        new_state = %{state | activities: activities, totals: totals}

        outputs = %{
          activity_totals: %{
            activities: activities,
            totals: totals
          }
        }

        {new_state, outputs}

      :team_assignment ->
        %{activity_id: activity_id, member: member, assigned: assigned} = input.data

        activities = update_assignment(state.activities, activity_id, member, assigned)
        new_state = %{state | activities: activities}

        outputs = %{
          activity_totals: %{
            activities: activities,
            totals: state.totals
          }
        }

        {new_state, outputs}

      _ ->
        {state, %{}}
    end
  end

  defp default_activities do
    %{
      preprocessing: %{
        id: :preprocessing,
        name: "PREPROCESSING",
        icon: "📁",
        color: "yellow",
        days_per_unit: 0.1,
        auto_pct: 90,
        base_days: 15,
        final_days: 1.5,
        assignments: %{"SB" => false, "CG" => false, "S2P" => true},
        children: [
          %{id: :ddls_ready, name: "DDLs Ready", days_per_unit: 0.3, auto_pct: 95, base_days: 3, final_days: 0.2, assignments: %{"SB" => false, "CG" => false, "S2P" => true}},
          %{id: :data_ready, name: "Data Ready", days_per_unit: 0.6, auto_pct: 80, base_days: 6, final_days: 1.2, assignments: %{"SB" => true, "CG" => false, "S2P" => false}},
          %{id: :mapping_flow_id, name: "Mapping Flow ID", days_per_unit: 0.1, auto_pct: 85, base_days: 6, final_days: 0.9, assignments: %{"SB" => false, "CG" => true, "S2P" => false}}
        ]
      },
      code_conversion: %{
        id: :code_conversion,
        name: "CODE CONVERSION",
        icon: "💻",
        color: "blue",
        days_per_unit: 0.1,
        auto_pct: 85,
        base_days: 30,
        final_days: 4.5,
        assignments: %{"SB" => false, "CG" => false, "S2P" => true},
        children: [
          %{id: :mapping_creation, name: "Mapping Creation", days_per_unit: 0.1, auto_pct: 90, base_days: 15, final_days: 1.5, assignments: %{"SB" => false, "CG" => false, "S2P" => true}},
          %{id: :code_execution, name: "Code Execution", days_per_unit: 0.1, auto_pct: 70, base_days: 15, final_days: 4.5, assignments: %{"SB" => false, "CG" => false, "S2P" => true}},
          %{id: :compile_validation, name: "Compile Validation", days_per_unit: 0.1, auto_pct: 60, base_days: 6, final_days: 2.4, assignments: %{"SB" => false, "CG" => true, "S2P" => false}}
        ]
      },
      execution_with_data: %{
        id: :execution_with_data,
        name: "EXECUTION WITH DATA",
        icon: "⚡",
        color: "purple",
        days_per_unit: 0.1,
        auto_pct: 65,
        base_days: 22.5,
        final_days: 7.9,
        assignments: %{"SB" => false, "CG" => true, "S2P" => false},
        children: [
          %{id: :data_verification, name: "Data Verification", days_per_unit: 0.1, auto_pct: 70, base_days: 7.5, final_days: 2.3, assignments: %{"SB" => false, "CG" => true, "S2P" => false}},
          %{id: :execute, name: "Execute", days_per_unit: 0.1, auto_pct: 95, base_days: 3.8, final_days: 0.2, assignments: %{"SB" => true, "CG" => false, "S2P" => false}},
          %{id: :validation_logs, name: "Validation & Logs", days_per_unit: 0.1, auto_pct: 50, base_days: 7.5, final_days: 3.8, assignments: %{"SB" => false, "CG" => true, "S2P" => false}},
          %{id: :debug_data_issues, name: "Debug Data Issues", days_per_unit: 0.1, auto_pct: 40, base_days: 3.8, final_days: 2.3, assignments: %{"SB" => false, "CG" => true, "S2P" => false}},
          %{id: :debug_code_issues, name: "Debug Code Issues", days_per_unit: 0.1, auto_pct: 30, base_days: 3, final_days: 2.1, assignments: %{"SB" => false, "CG" => true, "S2P" => false}}
        ]
      },
      post_processing: %{
        id: :post_processing,
        name: "POST PROCESSING",
        icon: "🚀",
        color: "green",
        days_per_unit: 0.1,
        auto_pct: 75,
        base_days: 15,
        final_days: 3.8,
        assignments: %{"SB" => true, "CG" => true, "S2P" => false},
        children: [
          %{id: :dev_to_sit, name: "Dev to SIT Movement", days_per_unit: 0.1, auto_pct: 80, base_days: 6, final_days: 1.2, assignments: %{"SB" => true, "CG" => true, "S2P" => false}},
          %{id: :integration_testing, name: "Integration Testing", days_per_unit: 0.1, auto_pct: 70, base_days: 6, final_days: 1.8, assignments: %{"SB" => false, "CG" => true, "S2P" => false}},
          %{id: :deployment_maintenance, name: "Deployment & Maintenance", days_per_unit: 0.1, auto_pct: 60, base_days: 3, final_days: 1.2, assignments: %{"SB" => true, "CG" => false, "S2P" => false}}
        ]
      }
    }
  end

  defp update_activity(activities, activity_id, field, value) do
    # Find and update the activity (could be parent or child)
    Enum.reduce(activities, %{}, fn {key, activity}, acc ->
      updated = cond do
        activity.id == activity_id ->
          Map.put(activity, field, value)
          |> recalculate_activity()

        Enum.any?(activity.children, & &1.id == activity_id) ->
          children = Enum.map(activity.children, fn child ->
            if child.id == activity_id do
              Map.put(child, field, value)
              |> recalculate_child()
            else
              child
            end
          end)
          recalculate_parent(%{activity | children: children})

        true ->
          activity
      end
      Map.put(acc, key, updated)
    end)
  end

  defp update_assignment(activities, activity_id, member, assigned) do
    Enum.reduce(activities, %{}, fn {key, activity}, acc ->
      updated = cond do
        activity.id == activity_id ->
          assignments = Map.put(activity.assignments, member, assigned)
          %{activity | assignments: assignments}

        Enum.any?(activity.children, & &1.id == activity_id) ->
          children = Enum.map(activity.children, fn child ->
            if child.id == activity_id do
              assignments = Map.put(child.assignments, member, assigned)
              %{child | assignments: assignments}
            else
              child
            end
          end)
          %{activity | children: children}

        true ->
          activity
      end
      Map.put(acc, key, updated)
    end)
  end

  defp recalculate_activity(activity) do
    final_days = activity.base_days * (1 - activity.auto_pct / 100)
    %{activity | final_days: Float.round(final_days, 1)}
  end

  defp recalculate_child(child) do
    final_days = child.base_days * (1 - child.auto_pct / 100)
    %{child | final_days: Float.round(final_days, 1)}
  end

  defp recalculate_parent(activity) do
    base_total = Enum.reduce(activity.children, 0, & &1.base_days + &2)
    final_total = Enum.reduce(activity.children, 0, & &1.final_days + &2)
    avg_auto = if base_total > 0, do: round((1 - final_total / base_total) * 100), else: 0

    %{activity |
      base_days: Float.round(base_total, 1),
      final_days: Float.round(final_total, 1),
      auto_pct: avg_auto
    }
  end

  defp calculate_totals(activities) do
    {base_sum, final_sum} = Enum.reduce(activities, {0, 0}, fn {_key, activity}, {base, final} ->
      {base + activity.base_days, final + activity.final_days}
    end)

    avg_auto = if base_sum > 0, do: round((1 - final_sum / base_sum) * 100), else: 0

    %{
      base_days: Float.round(base_sum, 1),
      final_days: Float.round(final_sum, 1),
      avg_auto_pct: avg_auto
    }
  end
end
