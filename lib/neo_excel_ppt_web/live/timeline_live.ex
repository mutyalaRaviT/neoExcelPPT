defmodule NeoExcelPPTWeb.TimelineLive do
  @moduledoc """
  LiveView for the event timeline and replay functionality.

  Features:
  - View all recorded events
  - Step forward/backward through events
  - Replay to a specific point in time
  - See the skill communication flow
  """
  use NeoExcelPPTWeb, :live_view

  alias NeoExcelPPT.Skills.{Channel, EventStore}

  import NeoExcelPPTWeb.CoreComponents

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Channel.subscribe(:event_store_updates)
    end

    events = EventStore.get_events()
    position = EventStore.get_position()

    socket =
      socket
      |> assign(:page_title, "Event Timeline")
      |> assign(:events, events)
      |> assign(:position, position)
      |> assign(:mode, :live)
      |> assign(:filter_skill, nil)
      |> assign(:filter_channel, nil)

    {:ok, socket}
  end

  @impl true
  def handle_info({:channel_update, :event_store_updates, {:new_event, event}}, socket) do
    events = socket.assigns.events ++ [event]
    position = EventStore.get_position()
    {:noreply, socket |> assign(:events, events) |> assign(:position, position)}
  end

  @impl true
  def handle_info({:channel_update, :event_store_updates, {:stepped_forward, _event}}, socket) do
    position = EventStore.get_position()
    {:noreply, assign(socket, :position, position)}
  end

  @impl true
  def handle_info({:channel_update, :event_store_updates, {:stepped_backward, _event}}, socket) do
    position = EventStore.get_position()
    {:noreply, assign(socket, :position, position)}
  end

  @impl true
  def handle_info({:channel_update, :event_store_updates, :cleared}, socket) do
    {:noreply, socket |> assign(:events, []) |> assign(:position, %{position: 0, total: 0, mode: :live})}
  end

  @impl true
  def handle_info({:channel_update, _, _}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("step_forward", _, socket) do
    case EventStore.step_forward() do
      {:ok, _event} ->
        position = EventStore.get_position()
        {:noreply, socket |> assign(:position, position) |> assign(:mode, :replay)}
      {:error, :at_end} ->
        {:noreply, put_flash(socket, :info, "Already at the end")}
    end
  end

  @impl true
  def handle_event("step_backward", _, socket) do
    case EventStore.step_backward() do
      {:ok, _event} ->
        position = EventStore.get_position()
        {:noreply, socket |> assign(:position, position) |> assign(:mode, :replay)}
      {:error, :at_start} ->
        {:noreply, put_flash(socket, :info, "Already at the start")}
    end
  end

  @impl true
  def handle_event("go_to_start", _, socket) do
    EventStore.replay_to_index(0)
    position = EventStore.get_position()
    {:noreply, socket |> assign(:position, position) |> assign(:mode, :replay)}
  end

  @impl true
  def handle_event("go_to_end", _, socket) do
    total = length(socket.assigns.events)
    EventStore.replay_to_index(total)
    position = EventStore.get_position()
    {:noreply, socket |> assign(:position, position) |> assign(:mode, :live)}
  end

  @impl true
  def handle_event("go_to_position", %{"index" => index_str}, socket) do
    {index, _} = Integer.parse(index_str)
    EventStore.replay_to_index(index)
    position = EventStore.get_position()
    {:noreply, socket |> assign(:position, position) |> assign(:mode, :replay)}
  end

  @impl true
  def handle_event("clear_events", _, socket) do
    EventStore.clear()
    {:noreply, socket |> assign(:events, []) |> assign(:position, %{position: 0, total: 0, mode: :live})}
  end

  @impl true
  def handle_event("filter_by_skill", %{"skill" => skill}, socket) do
    filter = if skill == "", do: nil, else: String.to_atom(skill)
    {:noreply, assign(socket, :filter_skill, filter)}
  end

  @impl true
  def handle_event("filter_by_channel", %{"channel" => channel}, socket) do
    filter = if channel == "", do: nil, else: String.to_atom(channel)
    {:noreply, assign(socket, :filter_channel, filter)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Header -->
      <div class="flex justify-between items-center">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">Event Timeline</h1>
          <p class="text-gray-500 mt-1">Replay and inspect skill communications</p>
        </div>
        <div class="flex items-center gap-4">
          <div class={"px-3 py-1 rounded-full text-sm font-medium #{mode_color(@mode)}"}>
            <%= String.upcase(to_string(@mode)) %> MODE
          </div>
          <.button variant="secondary" phx-click="clear_events">
            Clear All
          </.button>
        </div>
      </div>

      <!-- Playback Controls -->
      <.card>
        <div class="p-4">
          <div class="flex items-center justify-between">
            <!-- Controls -->
            <div class="flex items-center gap-2">
              <.button variant="ghost" phx-click="go_to_start" size="sm">
                ⏮️ Start
              </.button>
              <.button variant="ghost" phx-click="step_backward" size="sm">
                ⏪ Back
              </.button>
              <.button variant="ghost" phx-click="step_forward" size="sm">
                Forward ⏩
              </.button>
              <.button variant="ghost" phx-click="go_to_end" size="sm">
                End ⏭️
              </.button>
            </div>

            <!-- Position indicator -->
            <div class="flex items-center gap-4">
              <span class="text-sm text-gray-500">
                Position: <span class="font-mono font-bold"><%= @position.position %></span> / <%= @position.total %>
              </span>

              <!-- Progress bar -->
              <div class="w-64 h-2 bg-gray-200 rounded-full overflow-hidden">
                <div
                  class="h-full bg-blue-500 transition-all duration-200"
                  style={"width: #{if @position.total > 0, do: @position.position / @position.total * 100, else: 0}%"}
                >
                </div>
              </div>
            </div>
          </div>

          <!-- Timeline scrubber -->
          <%= if @position.total > 0 do %>
            <div class="mt-4">
              <input
                type="range"
                min="0"
                max={@position.total}
                value={@position.position}
                phx-change="go_to_position"
                phx-value-index={@position.position}
                name="index"
                class="w-full"
              />
            </div>
          <% end %>
        </div>
      </.card>

      <!-- Filters -->
      <.card>
        <div class="p-4 flex gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Filter by Skill</label>
            <select
              phx-change="filter_by_skill"
              name="skill"
              class="rounded-md border-gray-300 text-sm"
            >
              <option value="">All Skills</option>
              <%= for skill <- unique_skills(@events) do %>
                <option value={skill} selected={@filter_skill == skill}><%= skill %></option>
              <% end %>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Filter by Channel</label>
            <select
              phx-change="filter_by_channel"
              name="channel"
              class="rounded-md border-gray-300 text-sm"
            >
              <option value="">All Channels</option>
              <%= for channel <- unique_channels(@events) do %>
                <option value={channel} selected={@filter_channel == channel}><%= channel %></option>
              <% end %>
            </select>
          </div>
        </div>
      </.card>

      <!-- Events List -->
      <.card>
        <.card_header icon="📜" title="Event Log">
          <:actions>
            <span class="text-sm text-gray-500">
              <%= length(filtered_events(@events, @filter_skill, @filter_channel)) %> events
            </span>
          </:actions>
        </.card_header>
        <div class="divide-y divide-gray-100 max-h-[600px] overflow-y-auto">
          <%= for {event, index} <- Enum.with_index(filtered_events(@events, @filter_skill, @filter_channel)) do %>
            <div class={"p-4 #{if index < @position.position, do: "bg-green-50", else: "bg-white"}"}>
              <div class="flex items-start justify-between">
                <div class="flex items-start gap-3">
                  <!-- Index indicator -->
                  <div class={"w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold #{if index < @position.position, do: "bg-green-500 text-white", else: "bg-gray-200 text-gray-600"}"}>
                    <%= index + 1 %>
                  </div>

                  <div>
                    <div class="flex items-center gap-2">
                      <.badge color="blue"><%= event.skill %></.badge>
                      <span class="text-gray-400">published to</span>
                      <code class="px-2 py-0.5 bg-purple-100 text-purple-700 rounded text-sm">
                        <%= event.channel %>
                      </code>
                    </div>

                    <div class="mt-2 text-sm">
                      <div class="flex items-center gap-2">
                        <span class="text-red-500">-</span>
                        <code class="text-gray-600"><%= format_value(event.old_value) %></code>
                      </div>
                      <div class="flex items-center gap-2">
                        <span class="text-green-500">+</span>
                        <code class="text-gray-900 font-medium"><%= format_value(event.new_value) %></code>
                      </div>
                    </div>

                    <%= if event[:triggered_by] do %>
                      <div class="mt-2 text-xs text-gray-500">
                        Triggered by: <code><%= event.triggered_by %></code>
                      </div>
                    <% end %>
                  </div>
                </div>

                <div class="text-right">
                  <div class="text-xs text-gray-400">
                    <%= format_timestamp(event.timestamp) %>
                  </div>
                  <button
                    phx-click="go_to_position"
                    phx-value-index={index + 1}
                    class="mt-1 text-xs text-blue-600 hover:text-blue-800"
                  >
                    Go here →
                  </button>
                </div>
              </div>
            </div>
          <% end %>

          <%= if filtered_events(@events, @filter_skill, @filter_channel) == [] do %>
            <div class="p-8 text-center text-gray-500">
              <p class="text-lg">No events recorded</p>
              <p class="text-sm mt-2">Events will appear here as skills communicate</p>
            </div>
          <% end %>
        </div>
      </.card>

      <!-- Help Section -->
      <.card>
        <.card_header icon="💡" title="How Event Replay Works" />
        <div class="p-4 prose prose-sm max-w-none">
          <ul class="text-gray-600 space-y-2">
            <li>
              <strong>Live Mode:</strong> New events are recorded in real-time as skills communicate
            </li>
            <li>
              <strong>Replay Mode:</strong> Step through history to see how values changed over time
            </li>
            <li>
              <strong>Forward:</strong> Apply an event (sets the new value)
            </li>
            <li>
              <strong>Backward:</strong> Unapply an event (restores the old value)
            </li>
            <li>
              <strong>Green rows:</strong> Events that have been applied in the current replay position
            </li>
          </ul>
        </div>
      </.card>
    </div>
    """
  end

  defp mode_color(:live), do: "bg-green-100 text-green-800"
  defp mode_color(:replay), do: "bg-amber-100 text-amber-800"

  defp filtered_events(events, nil, nil), do: events
  defp filtered_events(events, skill, nil) when not is_nil(skill) do
    Enum.filter(events, &(&1.skill == skill))
  end
  defp filtered_events(events, nil, channel) when not is_nil(channel) do
    Enum.filter(events, &(&1.channel == channel))
  end
  defp filtered_events(events, skill, channel) do
    Enum.filter(events, &(&1.skill == skill && &1.channel == channel))
  end

  defp unique_skills(events) do
    events |> Enum.map(& &1.skill) |> Enum.uniq() |> Enum.sort()
  end

  defp unique_channels(events) do
    events |> Enum.map(& &1.channel) |> Enum.uniq() |> Enum.sort()
  end

  defp format_value(value) when is_map(value) do
    "{...}"
  end
  defp format_value(value) when is_list(value) do
    "[#{length(value)} items]"
  end
  defp format_value(nil), do: "nil"
  defp format_value(value), do: inspect(value)

  defp format_timestamp(datetime) do
    Calendar.strftime(datetime, "%H:%M:%S.%f")
  end
end
