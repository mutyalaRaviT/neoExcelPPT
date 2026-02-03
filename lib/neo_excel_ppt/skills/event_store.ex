defmodule NeoExcelPPT.Skills.EventStore do
  @moduledoc """
  Event Store for recording and replaying skill events.

  Implements event sourcing pattern:
  - All skill state changes are recorded as events
  - Events can be replayed forward or backward
  - Enables time-travel debugging
  - Provides full audit trail

  ## Event Structure

      %{
        id: "uuid",
        skill: :project_scope,
        channel: :total_files,
        old_value: 50000,
        new_value: 55000,
        triggered_by: :simple_files,
        timestamp: ~U[2024-01-15 10:30:00Z]
      }

  ## Usage

      # Record an event
      EventStore.record_event(%{skill: :my_skill, ...})

      # Get all events
      EventStore.get_events()

      # Replay to a specific point
      EventStore.replay_to(timestamp)
  """

  use GenServer

  alias NeoExcelPPT.Skills.Channel

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "Record a new event"
  def record_event(event) do
    GenServer.cast(__MODULE__, {:record, event})
  end

  @doc "Get all events, optionally filtered"
  def get_events(opts \\ []) do
    GenServer.call(__MODULE__, {:get_events, opts})
  end

  @doc "Get events for a specific skill"
  def get_events_for_skill(skill) do
    get_events(skill: skill)
  end

  @doc "Get events for a specific channel"
  def get_events_for_channel(channel) do
    get_events(channel: channel)
  end

  @doc "Get the current position in the event timeline"
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

  @doc "Replay to a specific timestamp"
  def replay_to(timestamp) do
    GenServer.call(__MODULE__, {:replay_to, timestamp})
  end

  @doc "Replay to a specific event index"
  def replay_to_index(index) do
    GenServer.call(__MODULE__, {:replay_to_index, index})
  end

  @doc "Clear all events"
  def clear do
    GenServer.cast(__MODULE__, :clear)
  end

  @doc "Subscribe to event notifications"
  def subscribe do
    Channel.subscribe(:event_store_updates)
  end

  # Server Callbacks

  @impl GenServer
  def init(_opts) do
    state = %{
      events: [],
      position: 0,  # Current replay position (0 = all events applied)
      mode: :live   # :live or :replay
    }
    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:record, event}, state) do
    event_with_id = Map.merge(event, %{
      id: UUID.uuid4(),
      recorded_at: DateTime.utc_now()
    })

    new_events = state.events ++ [event_with_id]
    new_state = %{state | events: new_events, position: length(new_events)}

    # Notify subscribers about new event
    Channel.publish(:event_store_updates, {:new_event, event_with_id})

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast(:clear, state) do
    Channel.publish(:event_store_updates, :cleared)
    {:noreply, %{state | events: [], position: 0}}
  end

  @impl GenServer
  def handle_call({:get_events, opts}, _from, state) do
    events = filter_events(state.events, opts)
    {:reply, events, state}
  end

  @impl GenServer
  def handle_call(:get_position, _from, state) do
    {:reply, %{position: state.position, total: length(state.events), mode: state.mode}, state}
  end

  @impl GenServer
  def handle_call(:step_forward, _from, state) do
    if state.position < length(state.events) do
      new_position = state.position + 1
      event = Enum.at(state.events, new_position - 1)

      # Apply the event (publish the new value)
      Channel.publish(event.channel, event.new_value)
      Channel.publish(:event_store_updates, {:stepped_forward, event})

      {:reply, {:ok, event}, %{state | position: new_position, mode: :replay}}
    else
      {:reply, {:error, :at_end}, state}
    end
  end

  @impl GenServer
  def handle_call(:step_backward, _from, state) do
    if state.position > 0 do
      event = Enum.at(state.events, state.position - 1)
      new_position = state.position - 1

      # Unapply the event (publish the old value)
      Channel.publish(event.channel, event.old_value)
      Channel.publish(:event_store_updates, {:stepped_backward, event})

      {:reply, {:ok, event}, %{state | position: new_position, mode: :replay}}
    else
      {:reply, {:error, :at_start}, state}
    end
  end

  @impl GenServer
  def handle_call({:replay_to, timestamp}, _from, state) do
    target_index = Enum.find_index(state.events, fn e ->
      DateTime.compare(e.timestamp, timestamp) == :gt
    end) || length(state.events)

    new_state = replay_to_position(state, target_index)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:replay_to_index, index}, _from, state) do
    clamped_index = max(0, min(index, length(state.events)))
    new_state = replay_to_position(state, clamped_index)
    {:reply, :ok, new_state}
  end

  # Private functions

  defp filter_events(events, opts) do
    events
    |> maybe_filter_by(:skill, opts[:skill])
    |> maybe_filter_by(:channel, opts[:channel])
    |> maybe_limit(opts[:limit])
  end

  defp maybe_filter_by(events, _key, nil), do: events
  defp maybe_filter_by(events, key, value) do
    Enum.filter(events, fn e -> Map.get(e, key) == value end)
  end

  defp maybe_limit(events, nil), do: events
  defp maybe_limit(events, limit), do: Enum.take(events, -limit)

  defp replay_to_position(state, target) when target == state.position do
    state
  end

  defp replay_to_position(state, target) when target > state.position do
    # Step forward
    events_to_apply = Enum.slice(state.events, state.position, target - state.position)
    Enum.each(events_to_apply, fn e ->
      Channel.publish(e.channel, e.new_value)
    end)
    %{state | position: target, mode: :replay}
  end

  defp replay_to_position(state, target) when target < state.position do
    # Step backward
    events_to_unapply = Enum.slice(state.events, target, state.position - target) |> Enum.reverse()
    Enum.each(events_to_unapply, fn e ->
      Channel.publish(e.channel, e.old_value)
    end)
    %{state | position: target, mode: :replay}
  end
end
