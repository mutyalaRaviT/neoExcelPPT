defmodule NeoExcelPPT.Skills.BufferCalculatorSkill do
  @moduledoc """
  Buffer Calculator Skill - Calculates project buffers.

  Pure Function: base_days -> buffer_breakdown

  Input Channels:
  - :base_days - Total effort from EffortAggregator

  Output Channels:
  - :buffer_days - Buffer breakdown and total
  """

  use NeoExcelPPT.Skills.Skill

  @impl true
  def skill_id, do: :buffer_calculator

  @impl true
  def input_channels, do: [:base_days, :buffer_config]

  @impl true
  def output_channels, do: [:buffer_days]

  @impl true
  def initial_state do
    %{
      base_days: 62.8,
      buffers: %{
        leave: %{name: "Leave Buffer", percentage: 15, days: 9.4, description: "Sick leaves, personal time, holidays, unplanned absenteeism"},
        dependency: %{name: "Dependency Buffer", percentage: 10, days: 6.3, description: "Delays from external teams or systems"},
        learning: %{name: "Learning Curve Buffer", percentage: 15, days: 9.4, description: "Onboarding and skill development time"}
      },
      total_buffer_days: 25.1,
      total_with_buffers: 87.9
    }
  end

  @impl true
  def compute(state, input) do
    case input.channel do
      :base_days ->
        base = input.data.manual_days || state.base_days
        recalculate_buffers(%{state | base_days: base})

      :buffer_config ->
        %{buffer_type: type, percentage: pct} = input.data
        buffers = Map.update!(state.buffers, type, fn b ->
          %{b | percentage: pct}
        end)
        recalculate_buffers(%{state | buffers: buffers})

      _ ->
        {state, %{}}
    end
  end

  defp recalculate_buffers(state) do
    base = state.base_days

    buffers = state.buffers
      |> Enum.map(fn {key, buffer} ->
        days = base * (buffer.percentage / 100)
        {key, %{buffer | days: Float.round(days, 1)}}
      end)
      |> Map.new()

    total_buffer = Enum.reduce(buffers, 0, fn {_, b}, acc -> acc + b.days end)
    total_with = base + total_buffer

    new_state = %{state |
      buffers: buffers,
      total_buffer_days: Float.round(total_buffer, 1),
      total_with_buffers: Float.round(total_with, 1)
    }

    outputs = %{
      buffer_days: %{
        buffers: Enum.map(buffers, fn {_k, v} -> v end),
        total_buffer_days: new_state.total_buffer_days,
        total_with_buffers: new_state.total_with_buffers
      }
    }

    {new_state, outputs}
  end
end
