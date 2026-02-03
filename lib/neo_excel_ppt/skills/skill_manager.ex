defmodule NeoExcelPPT.Skills.SkillManager do
  @moduledoc """
  Skill Manager - The Communication Orchestrator.

  Handles the "wiring" between skills:
  - Defines which skill outputs connect to which inputs
  - Initializes all skills on startup
  - Provides skill introspection for UI

  ## Wiring Configuration

  The wiring map defines how skills connect:

      %{
        "project_scope:output" => ["component_calculator:input", "effort_aggregator:input"],
        "component_calculator:output" => ["effort_aggregator:input"]
      }
  """

  use GenServer

  alias NeoExcelPPT.Skills.{Channel, HistoryTracker}

  # Default wiring configuration
  @default_wiring %{
    # ProjectScope outputs -> ComponentCalculator + EffortAggregator
    {:project_scope, :total_files} => [
      {:component_calculator, :file_count}
    ],
    {:project_scope, :component_breakdown} => [
      {:component_calculator, :breakdown},
      {:effort_aggregator, :components}
    ],

    # ComponentCalculator outputs -> EffortAggregator
    {:component_calculator, :scaled_effort} => [
      {:effort_aggregator, :component_effort}
    ],

    # ActivityCalculator outputs -> EffortAggregator
    {:activity_calculator, :activity_totals} => [
      {:effort_aggregator, :activity_effort}
    ],

    # EffortAggregator outputs -> BufferCalculator
    {:effort_aggregator, :total_days} => [
      {:buffer_calculator, :base_days}
    ]
  }

  # Skill modules to start
  @skill_modules [
    NeoExcelPPT.Skills.ProjectScopeSkill,
    NeoExcelPPT.Skills.ComponentCalculatorSkill,
    NeoExcelPPT.Skills.ActivityCalculatorSkill,
    NeoExcelPPT.Skills.EffortAggregatorSkill,
    NeoExcelPPT.Skills.BufferCalculatorSkill
  ]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Get the current wiring configuration"
  def get_wiring do
    GenServer.call(__MODULE__, :get_wiring)
  end

  @doc "Get all registered skills"
  def get_skills do
    GenServer.call(__MODULE__, :get_skills)
  end

  @doc "Get skill info by id"
  def get_skill(skill_id) do
    GenServer.call(__MODULE__, {:get_skill, skill_id})
  end

  @doc "Trigger an input to a specific skill"
  def send_input(skill_id, channel, data) do
    GenServer.cast(__MODULE__, {:send_input, skill_id, channel, data})
  end

  @doc "Update wiring at runtime"
  def update_wiring(new_wiring) do
    GenServer.cast(__MODULE__, {:update_wiring, new_wiring})
  end

  @doc "Get the dependency graph for visualization"
  def get_dependency_graph do
    GenServer.call(__MODULE__, :get_dependency_graph)
  end

  # Server Callbacks

  @impl GenServer
  def init(_opts) do
    # Subscribe to all output channels to route messages
    subscribe_to_outputs()

    state = %{
      wiring: @default_wiring,
      skills: %{},
      started: false
    }

    # Start skills after a small delay to ensure registry is ready
    Process.send_after(self(), :start_skills, 100)

    {:ok, state}
  end

  @impl GenServer
  def handle_info(:start_skills, state) do
    skills = start_all_skills()
    {:noreply, %{state | skills: skills, started: true}}
  end

  @impl GenServer
  def handle_info({:channel_message, channel, message}, state) do
    # Route the message based on wiring
    if state.started do
      route_message(channel, message, state.wiring)
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:get_wiring, _from, state) do
    {:reply, state.wiring, state}
  end

  @impl GenServer
  def handle_call(:get_skills, _from, state) do
    skill_list = Enum.map(state.skills, fn {id, info} ->
      %{
        id: id,
        module: info.module,
        input_channels: info.input_channels,
        output_channels: info.output_channels,
        status: if(Process.alive?(info.pid), do: :running, else: :stopped)
      }
    end)
    {:reply, skill_list, state}
  end

  @impl GenServer
  def handle_call({:get_skill, skill_id}, _from, state) do
    {:reply, Map.get(state.skills, skill_id), state}
  end

  @impl GenServer
  def handle_call(:get_dependency_graph, _from, state) do
    # Build a graph representation for visualization
    nodes = Enum.map(state.skills, fn {id, info} ->
      %{
        id: id,
        label: to_string(id),
        inputs: info.input_channels,
        outputs: info.output_channels
      }
    end)

    edges = Enum.flat_map(state.wiring, fn {{from_skill, from_channel}, targets} ->
      Enum.map(targets, fn {to_skill, to_channel} ->
        %{
          from: from_skill,
          to: to_skill,
          from_channel: from_channel,
          to_channel: to_channel
        }
      end)
    end)

    {:reply, %{nodes: nodes, edges: edges}, state}
  end

  @impl GenServer
  def handle_cast({:send_input, skill_id, channel, data}, state) do
    case Map.get(state.skills, skill_id) do
      %{module: module} ->
        module.process_input(%{channel: channel, data: data})
      nil ->
        :ok
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:update_wiring, new_wiring}, state) do
    {:noreply, %{state | wiring: new_wiring}}
  end

  # Private helpers

  defp start_all_skills do
    Enum.reduce(@skill_modules, %{}, fn module, acc ->
      case module.start_link([]) do
        {:ok, pid} ->
          skill_id = module.skill_id()
          info = %{
            module: module,
            pid: pid,
            input_channels: module.input_channels(),
            output_channels: module.output_channels()
          }
          Map.put(acc, skill_id, info)

        {:error, {:already_started, pid}} ->
          skill_id = module.skill_id()
          info = %{
            module: module,
            pid: pid,
            input_channels: module.input_channels(),
            output_channels: module.output_channels()
          }
          Map.put(acc, skill_id, info)

        error ->
          IO.puts("Failed to start skill #{module}: #{inspect(error)}")
          acc
      end
    end)
  end

  defp subscribe_to_outputs do
    # Subscribe to all possible output channels
    output_channels = [
      :total_files,
      :component_breakdown,
      :scaled_effort,
      :activity_totals,
      :total_days,
      :buffer_days,
      :_global_events
    ]

    Enum.each(output_channels, &Channel.subscribe/1)
  end

  defp route_message(channel, message, wiring) do
    # Find all targets for this channel
    source_skill = message[:from]

    if source_skill do
      key = {source_skill, channel}

      case Map.get(wiring, key) do
        nil -> :ok
        targets ->
          Enum.each(targets, fn {target_skill, target_channel} ->
            # Forward the message to the target skill's input
            send_to_skill(target_skill, target_channel, message.data)
          end)
      end
    end
  end

  defp send_to_skill(skill_id, channel, data) do
    # Get the skill module and send input
    module = skill_module_for(skill_id)
    if module do
      module.process_input(%{channel: channel, data: data})
    end
  end

  defp skill_module_for(skill_id) do
    case skill_id do
      :project_scope -> NeoExcelPPT.Skills.ProjectScopeSkill
      :component_calculator -> NeoExcelPPT.Skills.ComponentCalculatorSkill
      :activity_calculator -> NeoExcelPPT.Skills.ActivityCalculatorSkill
      :effort_aggregator -> NeoExcelPPT.Skills.EffortAggregatorSkill
      :buffer_calculator -> NeoExcelPPT.Skills.BufferCalculatorSkill
      _ -> nil
    end
  end
end
