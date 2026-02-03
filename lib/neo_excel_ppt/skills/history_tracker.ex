defmodule NeoExcelPPT.Skills.HistoryTracker do
  @moduledoc """
  History Tracker - The Tape.

  Central GenServer that:
  - Records all inter-skill messages
  - Enables time-travel (forward/backward playback)
  - Stores events in ETS for fast access
  - Broadcasts position changes to LiveViews

  ## Event Structure

      %{
        id: "uuid",
        skill_id: :project_scope,
        channel: :total_files,
        old_value: 50000,
        new_value: 55000,
        input: %{channel: :file_counts, data: %{simple: 55000}},
        timestamp: ~U[2024-01-15 10:30:00Z]
      }
  """

  use GenServer

  alias NeoExcelPPT.Skills.Channel

  @table :history_tracker_events

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "Record a new event to the tape"
  def record_event(event) do
    GenServer.cast(__MODULE__, {:record, event})
  end

  @doc "Get all events"
  def get_events do
    GenServer.call(__MODULE__, :get_events)
  end

  @doc "Get current position info"
  def get_position do
    GenServer.call(__MODULE__, :get_position)
  end

  @doc "Step forward one event"
  def step_forward do
    GenServer.call(__MODULE__, :step_forward)
  end

  @doc "Step backward one event"
  def step_backward do
    GenServer.call(__MODULE__, :step_backward)
  end

  @doc "Go to specific index"
  def goto_index(index) do
    GenServer.call(__MODULE__, {:goto, index})
  end

  @doc "Go to start (index 0)"
  def goto_start do
    goto_index(0)
  end

  @doc "Go to end (live mode)"
  def goto_end do
    GenServer.call(__MODULE__, :goto_end)
  end

  @doc "Clear all events"
  def clear do
    GenServer.cast(__MODULE__, :clear)
  end

  @doc "Get event at specific index"
  def get_event(index) do
    GenServer.call(__MODULE__, {:get_event, index})
  end

  # Server Callbacks

  @impl GenServer
  def init(_opts) do
    # Create ETS table for events
    :ets.new(@table, [:named_table, :ordered_set, :public, read_concurrency: true])

    state = %{
      position: 0,
      total: 0,
      mode: :live,  # :live or :replay
      next_id: 1
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:record, event}, state) do
    if state.mode == :live do
      # Add unique ID and index
      event_with_meta = event
        |> Map.put(:id, generate_id())
        |> Map.put(:index, state.next_id)

      # Store in ETS
      :ets.insert(@table, {state.next_id, event_with_meta})

      new_state = %{state |
        position: state.next_id,
        total: state.next_id,
        next_id: state.next_id + 1
      }

      # Broadcast event to global channel
      Channel.broadcast_global(%{
        type: :new_event,
        event: event_with_meta,
        position: new_state.position,
        total: new_state.total
      })

      {:noreply, new_state}
    else
      # In replay mode, don't record new events
      {:noreply, state}
    end
  end

  @impl GenServer
  def handle_cast(:clear, _state) do
    :ets.delete_all_objects(@table)

    new_state = %{
      position: 0,
      total: 0,
      mode: :live,
      next_id: 1
    }

    Channel.broadcast_global(%{type: :cleared})

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_call(:get_events, _from, state) do
    events = :ets.tab2list(@table)
      |> Enum.sort_by(fn {idx, _} -> idx end)
      |> Enum.map(fn {_, event} -> event end)

    {:reply, events, state}
  end

  @impl GenServer
  def handle_call(:get_position, _from, state) do
    {:reply, %{position: state.position, total: state.total, mode: state.mode}, state}
  end

  @impl GenServer
  def handle_call(:step_forward, _from, state) do
    if state.position < state.total do
      new_position = state.position + 1
      event = get_event_at(new_position)

      # Apply the event (set new value)
      if event do
        apply_event_forward(event)
      end

      new_state = %{state | position: new_position, mode: :replay}

      Channel.broadcast_global(%{
        type: :position_changed,
        position: new_position,
        total: state.total,
        mode: :replay,
        event: event
      })

      {:reply, {:ok, event}, new_state}
    else
      {:reply, {:error, :at_end}, state}
    end
  end

  @impl GenServer
  def handle_call(:step_backward, _from, state) do
    if state.position > 0 do
      event = get_event_at(state.position)

      # Unapply the event (restore old value)
      if event do
        apply_event_backward(event)
      end

      new_position = state.position - 1
      new_state = %{state | position: new_position, mode: :replay}

      Channel.broadcast_global(%{
        type: :position_changed,
        position: new_position,
        total: state.total,
        mode: :replay,
        event: event
      })

      {:reply, {:ok, event}, new_state}
    else
      {:reply, {:error, :at_start}, state}
    end
  end

  @impl GenServer
  def handle_call({:goto, target_index}, _from, state) do
    target = max(0, min(target_index, state.total))

    # Determine direction and apply/unapply events
    cond do
      target > state.position ->
        # Going forward
        Enum.each((state.position + 1)..target, fn idx ->
          event = get_event_at(idx)
          if event, do: apply_event_forward(event)
        end)

      target < state.position ->
        # Going backward
        Enum.each(state.position..target//-1, fn idx ->
          if idx > target do
            event = get_event_at(idx)
            if event, do: apply_event_backward(event)
          end
        end)

      true ->
        :ok
    end

    new_state = %{state | position: target, mode: if(target == state.total, do: :live, else: :replay)}

    Channel.broadcast_global(%{
      type: :position_changed,
      position: target,
      total: state.total,
      mode: new_state.mode
    })

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:goto_end, _from, state) do
    # Apply all remaining events
    if state.position < state.total do
      Enum.each((state.position + 1)..state.total, fn idx ->
        event = get_event_at(idx)
        if event, do: apply_event_forward(event)
      end)
    end

    new_state = %{state | position: state.total, mode: :live}

    Channel.broadcast_global(%{
      type: :position_changed,
      position: state.total,
      total: state.total,
      mode: :live
    })

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:get_event, index}, _from, state) do
    event = get_event_at(index)
    {:reply, event, state}
  end

  # Private helpers

  defp get_event_at(index) do
    case :ets.lookup(@table, index) do
      [{^index, event}] -> event
      [] -> nil
    end
  end

  defp apply_event_forward(event) do
    # Send force_state to the skill with the new value
    skill_module = skill_module_for(event.skill_id)
    if skill_module do
      new_state = %{event.channel => event.new_value}
      skill_module.force_state(new_state)
    end
  end

  defp apply_event_backward(event) do
    # Send force_state to the skill with the old value
    skill_module = skill_module_for(event.skill_id)
    if skill_module do
      old_state = %{event.channel => event.old_value}
      skill_module.force_state(old_state)
    end
  end

  defp skill_module_for(skill_id) do
    # Map skill_id to module name
    case skill_id do
      :project_scope -> NeoExcelPPT.Skills.ProjectScopeSkill
      :component_calculator -> NeoExcelPPT.Skills.ComponentCalculatorSkill
      :activity_calculator -> NeoExcelPPT.Skills.ActivityCalculatorSkill
      :effort_aggregator -> NeoExcelPPT.Skills.EffortAggregatorSkill
      :buffer_calculator -> NeoExcelPPT.Skills.BufferCalculatorSkill
      _ -> nil
    end
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
