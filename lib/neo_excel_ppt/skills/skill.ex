defmodule NeoExcelPPT.Skills.Skill do
  @moduledoc """
  Skill Behavior - The Actor Blueprint.

  A Skill is a pure function wrapper that:
  - Subscribes to input channels
  - Processes inputs through a pure function
  - Emits outputs to output channels
  - Records all state changes to the History Tracker

  ## Usage

      defmodule MySkill do
        use NeoExcelPPT.Skills.Skill

        @impl true
        def skill_id, do: :my_skill

        @impl true
        def input_channels, do: [:input_a, :input_b]

        @impl true
        def output_channels, do: [:result]

        @impl true
        def initial_state, do: %{value: 0}

        @impl true
        def compute(state, input) do
          new_value = state.value + input.data
          {%{state | value: new_value}, %{result: new_value}}
        end
      end
  """

  @doc "Unique identifier for this skill"
  @callback skill_id() :: atom()

  @doc "List of channels this skill listens to"
  @callback input_channels() :: [atom()]

  @doc "List of channels this skill publishes to"
  @callback output_channels() :: [atom()]

  @doc "Initial state for the skill"
  @callback initial_state() :: map()

  @doc "Pure function: (state, input) -> {new_state, outputs}"
  @callback compute(state :: map(), input :: map()) :: {map(), map()}

  @doc "Optional: Render function for LiveComponent"
  @callback render(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @optional_callbacks [render: 1]

  defmacro __using__(_opts) do
    quote do
      @behaviour NeoExcelPPT.Skills.Skill
      use GenServer

      alias NeoExcelPPT.Skills.{Channel, HistoryTracker}

      # Client API

      def start_link(opts \\ []) do
        GenServer.start_link(__MODULE__, opts, name: via_tuple())
      end

      def get_state do
        GenServer.call(via_tuple(), :get_state)
      end

      def force_state(state) do
        GenServer.cast(via_tuple(), {:force_state, state})
      end

      def process_input(input) do
        GenServer.cast(via_tuple(), {:process_input, input})
      end

      defp via_tuple do
        {:via, Registry, {NeoExcelPPT.Skills.Registry, skill_id()}}
      end

      # Server Callbacks

      @impl GenServer
      def init(_opts) do
        # Subscribe to all input channels
        Enum.each(input_channels(), &Channel.subscribe/1)

        state = %{
          skill_id: skill_id(),
          data: initial_state(),
          input_channels: input_channels(),
          output_channels: output_channels()
        }

        {:ok, state}
      end

      @impl GenServer
      def handle_call(:get_state, _from, state) do
        {:reply, state.data, state}
      end

      @impl GenServer
      def handle_cast({:force_state, new_data}, state) do
        # Used for time-travel - directly set state without side effects
        {:noreply, %{state | data: new_data}}
      end

      @impl GenServer
      def handle_cast({:process_input, input}, state) do
        handle_input_message(input, state)
      end

      @impl GenServer
      def handle_info({:channel_message, channel, message}, state) do
        if channel in state.input_channels do
          handle_input_message(%{channel: channel, data: message}, state)
        else
          {:noreply, state}
        end
      end

      defp handle_input_message(input, state) do
        old_data = state.data

        # Call the pure compute function
        {new_data, outputs} = compute(old_data, input)

        # Record to history tracker
        Enum.each(outputs, fn {channel, value} ->
          old_value = Map.get(old_data, channel)
          HistoryTracker.record_event(%{
            skill_id: state.skill_id,
            channel: channel,
            old_value: old_value,
            new_value: value,
            input: input,
            timestamp: DateTime.utc_now()
          })

          # Broadcast to output channels
          Channel.broadcast(channel, %{
            from: state.skill_id,
            data: value
          })
        end)

        {:noreply, %{state | data: new_data}}
      end

      # Default implementations
      def initial_state, do: %{}

      defoverridable [initial_state: 0]
    end
  end
end
