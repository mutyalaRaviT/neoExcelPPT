defmodule NeoExcelPPT.Skills.Skill do
  @moduledoc """
  Behaviour definition for Skills.

  A Skill is an actor (GenServer) that:
  - Has a unique name
  - Subscribes to input channels
  - Publishes to output channels
  - Contains a pure function for computation
  - Records all state changes to EventStore

  Skills are the fundamental building blocks that communicate
  through channels, enabling reactive, composable computations.

  ## Example

      defmodule MySkill do
        use NeoExcelPPT.Skills.Skill

        @impl true
        def name, do: :my_skill

        @impl true
        def input_channels, do: [:value_a, :value_b]

        @impl true
        def output_channels, do: [:result]

        @impl true
        def compute(%{value_a: a, value_b: b}) do
          %{result: a + b}
        end
      end
  """

  @doc "Unique name for this skill"
  @callback name() :: atom()

  @doc "List of channel names this skill subscribes to"
  @callback input_channels() :: [atom()]

  @doc "List of channel names this skill publishes to"
  @callback output_channels() :: [atom()]

  @doc "Pure function that computes outputs from inputs"
  @callback compute(inputs :: map()) :: outputs :: map()

  @doc "Optional: Initialize default state"
  @callback initial_state() :: map()

  @optional_callbacks [initial_state: 0]

  defmacro __using__(_opts) do
    quote do
      use GenServer
      @behaviour NeoExcelPPT.Skills.Skill

      alias NeoExcelPPT.Skills.{Channel, EventStore}

      # Default implementation
      def initial_state, do: %{}

      defoverridable initial_state: 0

      # Client API

      def start_link(opts \\ []) do
        GenServer.start_link(__MODULE__, opts, name: via_tuple())
      end

      def get_state do
        GenServer.call(via_tuple(), :get_state)
      end

      def get_outputs do
        GenServer.call(via_tuple(), :get_outputs)
      end

      def update_input(channel, value) do
        GenServer.cast(via_tuple(), {:update_input, channel, value})
      end

      defp via_tuple do
        {:via, Registry, {NeoExcelPPT.Skills.ProcessRegistry, name()}}
      end

      # Server Callbacks

      @impl GenServer
      def init(_opts) do
        # Subscribe to all input channels
        Enum.each(input_channels(), &Channel.subscribe/1)

        state = %{
          inputs: initial_state(),
          outputs: %{},
          last_computed_at: nil
        }

        {:ok, state}
      end

      @impl GenServer
      def handle_call(:get_state, _from, state) do
        {:reply, state, state}
      end

      @impl GenServer
      def handle_call(:get_outputs, _from, state) do
        {:reply, state.outputs, state}
      end

      @impl GenServer
      def handle_cast({:update_input, channel, value}, state) do
        new_inputs = Map.put(state.inputs, channel, value)
        new_outputs = compute(new_inputs)
        now = DateTime.utc_now()

        # Record event for each changed output
        Enum.each(new_outputs, fn {out_channel, out_value} ->
          old_value = Map.get(state.outputs, out_channel)

          if old_value != out_value do
            EventStore.record_event(%{
              skill: name(),
              channel: out_channel,
              old_value: old_value,
              new_value: out_value,
              triggered_by: channel,
              timestamp: now
            })

            # Publish to output channel
            Channel.publish(out_channel, out_value)
          end
        end)

        new_state = %{state | inputs: new_inputs, outputs: new_outputs, last_computed_at: now}
        {:noreply, new_state}
      end

      @impl GenServer
      def handle_info({:channel_update, channel, value}, state) do
        # Received update from a subscribed channel
        handle_cast({:update_input, channel, value}, state)
      end
    end
  end
end
