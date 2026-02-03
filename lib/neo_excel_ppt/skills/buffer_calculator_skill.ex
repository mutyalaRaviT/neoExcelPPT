defmodule NeoExcelPPT.Skills.BufferCalculatorSkill do
  @moduledoc """
  Skill for calculating project buffers.

  Buffer Types:
  - Leave Buffer (15%) - Sick leaves, personal time, holidays, unplanned absenteeism
  - Dependency Buffer (10%) - Delays from external teams or systems
  - Learning Curve Buffer (15%) - Onboarding and skill development time

  Input Channels:
  - :total_final_days from EffortAggregatorSkill

  Output Channels:
  - :proposed_buffers
  - :total_with_buffers
  """

  use NeoExcelPPT.Skills.Skill

  @impl true
  def name, do: :buffer_calculator

  @impl true
  def input_channels do
    [
      :total_final_days,
      :leave_buffer_pct,
      :dependency_buffer_pct,
      :learning_buffer_pct
    ]
  end

  @impl true
  def output_channels do
    [
      :proposed_buffers,
      :total_with_buffers
    ]
  end

  @impl true
  def initial_state do
    %{
      total_final_days: 62.8,
      leave_buffer_pct: 15,
      dependency_buffer_pct: 10,
      learning_buffer_pct: 15
    }
  end

  @impl true
  def compute(inputs) do
    total_days = Map.get(inputs, :total_final_days, 62.8)
    leave_pct = Map.get(inputs, :leave_buffer_pct, 15)
    dependency_pct = Map.get(inputs, :dependency_buffer_pct, 10)
    learning_pct = Map.get(inputs, :learning_buffer_pct, 15)

    leave_buffer = total_days * (leave_pct / 100)
    dependency_buffer = total_days * (dependency_pct / 100)
    learning_buffer = total_days * (learning_pct / 100)

    total_buffer = leave_buffer + dependency_buffer + learning_buffer
    total_with_buffers = total_days + total_buffer

    %{
      proposed_buffers: %{
        buffers: [
          %{
            type: "Leave Buffer",
            percentage: leave_pct,
            days: Float.round(leave_buffer, 1),
            description: "Sick leaves, personal time, holidays, unplanned absenteeism"
          },
          %{
            type: "Dependency Buffer",
            percentage: dependency_pct,
            days: Float.round(dependency_buffer, 1),
            description: "Delays from external teams or systems"
          },
          %{
            type: "Learning Curve Buffer",
            percentage: learning_pct,
            days: Float.round(learning_buffer, 1),
            description: "Onboarding and skill development time"
          }
        ],
        total_buffer_days: Float.round(total_buffer, 1),
        total_buffer_pct: leave_pct + dependency_pct + learning_pct
      },
      total_with_buffers: Float.round(total_with_buffers, 1)
    }
  end
end
