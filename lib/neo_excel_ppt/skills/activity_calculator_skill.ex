defmodule NeoExcelPPT.Skills.ActivityCalculatorSkill do
  @moduledoc """
  Skill for calculating activity/task effort.

  Manages the activities table with:
  - Team assignments (SB, CG, S2P)
  - Days per unit
  - Automation percentages
  - Base and final day calculations

  Categories:
  - PREPROCESSING (DDLs Ready, Data Ready, Mapping Flow ID)
  - CODE CONVERSION (Mapping Creation, Code Execution, Compile Validation)
  - EXECUTION WITH DATA (Data Verification, Execute, Validation & Logs, Debug Data Issues, Debug Code Issues)
  - POST PROCESSING (Dev to SIT Movement, Integration Testing, Deployment & Maintenance)
  """

  use NeoExcelPPT.Skills.Skill

  @impl true
  def name, do: :activity_calculator

  @impl true
  def input_channels do
    [
      :activity_updates,
      :team_assignment_updates,
      :total_components
    ]
  end

  @impl true
  def output_channels do
    [
      :activities_summary,
      :total_base_days,
      :total_final_days,
      :activities_by_category
    ]
  end

  @impl true
  def initial_state do
    %{
      activities: default_activities(),
      total_components: 874_500
    }
  end

  @impl true
  def compute(inputs) do
    activities = Map.get(inputs, :activities, default_activities())

    # Group by category and calculate totals
    by_category = Enum.group_by(activities, & &1.category)

    category_summaries = Enum.map(by_category, fn {cat, acts} ->
      cat_base = Enum.reduce(acts, 0, fn a, acc -> acc + a.base_days end)
      cat_final = Enum.reduce(acts, 0, fn a, acc -> acc + calculate_final_days(a) end)
      cat_auto = if cat_base > 0, do: Float.round((cat_base - cat_final) / cat_base * 100, 0), else: 0

      %{
        category: cat,
        activities: acts,
        total_base: cat_base,
        total_final: cat_final,
        auto_pct: cat_auto
      }
    end)

    total_base = Enum.reduce(activities, 0, fn a, acc -> acc + a.base_days end)
    total_final = Enum.reduce(activities, 0, fn a, acc -> acc + calculate_final_days(a) end)
    avg_auto = if total_base > 0, do: Float.round((total_base - total_final) / total_base * 100, 0), else: 0

    %{
      activities_summary: %{
        categories: category_summaries,
        totals: %{
          base_days: total_base,
          final_days: total_final,
          auto_pct: avg_auto
        }
      },
      total_base_days: total_base,
      total_final_days: total_final,
      activities_by_category: by_category
    }
  end

  defp calculate_final_days(activity) do
    activity.base_days * (1 - activity.auto_pct / 100)
  end

  defp default_activities do
    [
      # PREPROCESSING
      %{
        id: "prep",
        name: "PREPROCESSING",
        category: :preprocessing,
        is_category: true,
        team: %{sb: false, cg: false, s2p: true},
        days_unit: 0.1,
        auto_pct: 90,
        base_days: 15,
        children: ["ddls_ready", "data_ready", "mapping_flow_id"]
      },
      %{
        id: "ddls_ready",
        name: "DDLs Ready",
        category: :preprocessing,
        is_category: false,
        team: %{sb: false, cg: false, s2p: true},
        days_unit: 0.3,
        auto_pct: 95,
        base_days: 3
      },
      %{
        id: "data_ready",
        name: "Data Ready",
        category: :preprocessing,
        is_category: false,
        team: %{sb: true, cg: false, s2p: false},
        days_unit: 0.6,
        auto_pct: 80,
        base_days: 6
      },
      %{
        id: "mapping_flow_id",
        name: "Mapping Flow ID",
        category: :preprocessing,
        is_category: false,
        team: %{sb: false, cg: true, s2p: false},
        days_unit: 0.1,
        auto_pct: 85,
        base_days: 6
      },

      # CODE CONVERSION
      %{
        id: "code_conv",
        name: "CODE CONVERSION",
        category: :code_conversion,
        is_category: true,
        team: %{sb: false, cg: false, s2p: true},
        days_unit: 0.1,
        auto_pct: 85,
        base_days: 30,
        children: ["mapping_creation", "code_execution", "compile_validation"]
      },
      %{
        id: "mapping_creation",
        name: "Mapping Creation",
        category: :code_conversion,
        is_category: false,
        team: %{sb: false, cg: false, s2p: true},
        days_unit: 0.1,
        auto_pct: 90,
        base_days: 15
      },
      %{
        id: "code_execution",
        name: "Code Execution",
        category: :code_conversion,
        is_category: false,
        team: %{sb: false, cg: false, s2p: true},
        days_unit: 0.1,
        auto_pct: 70,
        base_days: 15
      },
      %{
        id: "compile_validation",
        name: "Compile Validation",
        category: :code_conversion,
        is_category: false,
        team: %{sb: false, cg: true, s2p: false},
        days_unit: 0.1,
        auto_pct: 60,
        base_days: 6
      },

      # EXECUTION WITH DATA
      %{
        id: "exec_data",
        name: "EXECUTION WITH DATA",
        category: :execution_with_data,
        is_category: true,
        team: %{sb: false, cg: true, s2p: false},
        days_unit: 0.1,
        auto_pct: 65,
        base_days: 22.5,
        children: ["data_verification", "execute", "validation_logs", "debug_data", "debug_code"]
      },
      %{
        id: "data_verification",
        name: "Data Verification",
        category: :execution_with_data,
        is_category: false,
        team: %{sb: false, cg: true, s2p: false},
        days_unit: 0.1,
        auto_pct: 70,
        base_days: 7.5
      },
      %{
        id: "execute",
        name: "Execute",
        category: :execution_with_data,
        is_category: false,
        team: %{sb: true, cg: false, s2p: false},
        days_unit: 0.1,
        auto_pct: 95,
        base_days: 3.8
      },
      %{
        id: "validation_logs",
        name: "Validation & Logs",
        category: :execution_with_data,
        is_category: false,
        team: %{sb: false, cg: false, s2p: true},
        days_unit: 0.1,
        auto_pct: 50,
        base_days: 7.5
      },
      %{
        id: "debug_data",
        name: "Debug Data Issues",
        category: :execution_with_data,
        is_category: false,
        team: %{sb: false, cg: true, s2p: false},
        days_unit: 0.1,
        auto_pct: 40,
        base_days: 3.8
      },
      %{
        id: "debug_code",
        name: "Debug Code Issues",
        category: :execution_with_data,
        is_category: false,
        team: %{sb: false, cg: true, s2p: false},
        days_unit: 0.1,
        auto_pct: 30,
        base_days: 3
      },

      # POST PROCESSING
      %{
        id: "post_proc",
        name: "POST PROCESSING",
        category: :post_processing,
        is_category: true,
        team: %{sb: true, cg: true, s2p: false},
        days_unit: 0.1,
        auto_pct: 75,
        base_days: 15,
        children: ["dev_sit", "integration_test", "deployment"]
      },
      %{
        id: "dev_sit",
        name: "Dev to SIT Movement",
        category: :post_processing,
        is_category: false,
        team: %{sb: true, cg: true, s2p: false},
        days_unit: 0.1,
        auto_pct: 80,
        base_days: 6
      },
      %{
        id: "integration_test",
        name: "Integration Testing",
        category: :post_processing,
        is_category: false,
        team: %{sb: false, cg: true, s2p: false},
        days_unit: 0.1,
        auto_pct: 70,
        base_days: 6
      },
      %{
        id: "deployment",
        name: "Deployment & Maintenance",
        category: :post_processing,
        is_category: false,
        team: %{sb: true, cg: false, s2p: false},
        days_unit: 0.1,
        auto_pct: 60,
        base_days: 3
      }
    ]
  end
end
