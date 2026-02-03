defmodule NeoExcelPPTWeb.TimelineLive do
  @moduledoc """
  Timeline LiveView - The Time-Travel UI.

  Shows the event history (The Tape) and provides controls for:
  - Stepping forward/backward through events
  - Jumping to specific points in time
  - Viewing the skill communication flow

  All elements have proper IDs for Puppeteer/Playwright testing.
  """

  use NeoExcelPPTWeb, :live_view

  alias NeoExcelPPT.Skills.{Channel, HistoryTracker}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Channel.subscribe(:_global_events)
    end

    events = HistoryTracker.get_events()
    position = HistoryTracker.get_position()

    socket =
      socket
      |> assign(:page_title, "Event Timeline")
      |> assign(:events, events)
      |> assign(:position, position.position)
      |> assign(:total, position.total)
      |> assign(:mode, position.mode)
      |> assign(:playing, false)
      |> assign(:playback_speed, 1000)

    {:ok, socket}
  end

  @impl true
  def handle_info({:channel_message, :_global_events, event}, socket) do
    socket = case event.type do
      :new_event ->
        events = socket.assigns.events ++ [event.event]
        socket
        |> assign(:events, events)
        |> assign(:position, event.position)
        |> assign(:total, event.total)

      :position_changed ->
        socket
        |> assign(:position, event.position)
        |> assign(:total, event.total)
        |> assign(:mode, event.mode)

      :cleared ->
        socket
        |> assign(:events, [])
        |> assign(:position, 0)
        |> assign(:total, 0)
        |> assign(:mode, :live)

      _ ->
        socket
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info(:playback_tick, socket) do
    if socket.assigns.playing && socket.assigns.position < socket.assigns.total do
      HistoryTracker.step_forward()
      Process.send_after(self(), :playback_tick, socket.assigns.playback_speed)
      {:noreply, socket}
    else
      {:noreply, assign(socket, :playing, false)}
    end
  end

  @impl true
  def handle_event("step_forward", _, socket) do
    HistoryTracker.step_forward()
    {:noreply, socket}
  end

  @impl true
  def handle_event("step_backward", _, socket) do
    HistoryTracker.step_backward()
    {:noreply, socket}
  end

  @impl true
  def handle_event("goto_start", _, socket) do
    HistoryTracker.goto_start()
    {:noreply, socket}
  end

  @impl true
  def handle_event("goto_end", _, socket) do
    HistoryTracker.goto_end()
    {:noreply, socket}
  end

  @impl true
  def handle_event("goto_position", %{"position" => pos_str}, socket) do
    {pos, _} = Integer.parse(pos_str)
    HistoryTracker.goto_index(pos)
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_play", _, socket) do
    playing = !socket.assigns.playing

    if playing do
      Process.send_after(self(), :playback_tick, socket.assigns.playback_speed)
    end

    {:noreply, assign(socket, :playing, playing)}
  end

  @impl true
  def handle_event("set_speed", %{"speed" => speed_str}, socket) do
    {speed, _} = Integer.parse(speed_str)
    {:noreply, assign(socket, :playback_speed, speed)}
  end

  @impl true
  def handle_event("clear_events", _, socket) do
    HistoryTracker.clear()
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="timeline-container" class="min-h-screen bg-gray-50 p-6">
      <div class="max-w-5xl mx-auto space-y-6">

        <!-- Header -->
        <div class="flex justify-between items-center">
          <div>
            <h1 class="text-2xl font-bold text-gray-900">Event Timeline</h1>
            <p class="text-gray-500 mt-1">Time-travel through skill communications</p>
          </div>
          <div class="flex items-center gap-4">
            <div id="timeline-mode" class={"px-3 py-1 rounded-full text-sm font-medium #{mode_class(@mode)}"}>
              <%= String.upcase(to_string(@mode)) %> MODE
            </div>
            <button
              phx-click="clear_events"
              class="px-4 py-2 text-sm text-red-600 border border-red-200 rounded-lg hover:bg-red-50"
            >
              Clear All
            </button>
          </div>
        </div>

        <!-- Playback Controls -->
        <div id="timeline-controls" class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div class="flex items-center justify-between mb-4">
            <!-- Control Buttons -->
            <div class="flex items-center gap-2">
              <button
                id="timeline-btn-start"
                phx-click="goto_start"
                class="p-2 rounded-lg border border-gray-200 hover:bg-gray-50"
                title="Go to Start"
              >
                ⏮️
              </button>
              <button
                id="timeline-btn-back"
                phx-click="step_backward"
                class="p-2 rounded-lg border border-gray-200 hover:bg-gray-50"
                title="Step Backward"
              >
                ⏪
              </button>
              <button
                id="timeline-btn-play"
                phx-click="toggle_play"
                class={"p-3 rounded-lg #{if @playing, do: "bg-red-500 text-white", else: "bg-blue-500 text-white"} hover:opacity-90"}
                title={if @playing, do: "Pause", else: "Play"}
              >
                <%= if @playing, do: "⏸️", else: "▶️" %>
              </button>
              <button
                id="timeline-btn-forward"
                phx-click="step_forward"
                class="p-2 rounded-lg border border-gray-200 hover:bg-gray-50"
                title="Step Forward"
              >
                ⏩
              </button>
              <button
                id="timeline-btn-end"
                phx-click="goto_end"
                class="p-2 rounded-lg border border-gray-200 hover:bg-gray-50"
                title="Go to End (Live)"
              >
                ⏭️
              </button>
            </div>

            <!-- Position Display -->
            <div id="timeline-position" class="text-center">
              <span class="text-2xl font-mono font-bold"><%= @position %></span>
              <span class="text-gray-400"> / </span>
              <span class="text-lg font-mono text-gray-500"><%= @total %></span>
            </div>

            <!-- Speed Control -->
            <div class="flex items-center gap-2">
              <span class="text-sm text-gray-500">Speed:</span>
              <select
                phx-change="set_speed"
                name="speed"
                class="border rounded px-2 py-1 text-sm"
              >
                <option value="2000" selected={@playback_speed == 2000}>0.5x</option>
                <option value="1000" selected={@playback_speed == 1000}>1x</option>
                <option value="500" selected={@playback_speed == 500}>2x</option>
                <option value="250" selected={@playback_speed == 250}>4x</option>
              </select>
            </div>
          </div>

          <!-- Scrubber -->
          <div class="relative">
            <input
              id="timeline-scrubber"
              type="range"
              min="0"
              max={@total}
              value={@position}
              phx-change="goto_position"
              name="position"
              class="w-full h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer"
            />
            <div class="flex justify-between text-xs text-gray-400 mt-1">
              <span>Start</span>
              <span>End (Live)</span>
            </div>
          </div>
        </div>

        <!-- Events List -->
        <div class="bg-white rounded-xl shadow-sm border border-gray-200">
          <div class="flex items-center justify-between p-4 border-b border-gray-100">
            <div class="flex items-center gap-2">
              <span class="text-xl">📜</span>
              <h2 class="text-lg font-semibold text-gray-900">Event Log</h2>
            </div>
            <span class="text-sm text-gray-500"><%= length(@events) %> events</span>
          </div>

          <div class="divide-y divide-gray-100 max-h-[500px] overflow-y-auto">
            <%= if @events == [] do %>
              <div class="p-8 text-center text-gray-500">
                <p class="text-lg">No events recorded</p>
                <p class="text-sm mt-2">Events will appear here as skills communicate</p>
              </div>
            <% else %>
              <%= for {event, index} <- Enum.with_index(@events) do %>
                <div
                  id={"timeline-event-#{index}"}
                  class={"p-4 cursor-pointer hover:bg-gray-50 #{if index < @position, do: "bg-green-50", else: ""}"}
                  phx-click="goto_position"
                  phx-value-position={index + 1}
                >
                  <div class="flex items-start justify-between">
                    <div class="flex items-start gap-3">
                      <!-- Index Badge -->
                      <div class={"w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold #{if index < @position, do: "bg-green-500 text-white", else: "bg-gray-200 text-gray-600"}"}>
                        <%= index + 1 %>
                      </div>

                      <div>
                        <div class="flex items-center gap-2">
                          <span class="px-2 py-0.5 bg-blue-100 text-blue-700 rounded text-sm font-medium">
                            <%= event.skill_id %>
                          </span>
                          <span class="text-gray-400">→</span>
                          <code class="px-2 py-0.5 bg-purple-100 text-purple-700 rounded text-sm">
                            <%= event.channel %>
                          </code>
                        </div>

                        <div class="mt-2 text-sm space-y-1">
                          <div class="flex items-center gap-2">
                            <span class="text-red-500 font-mono">-</span>
                            <code class="text-gray-500"><%= format_value(event.old_value) %></code>
                          </div>
                          <div class="flex items-center gap-2">
                            <span class="text-green-500 font-mono">+</span>
                            <code class="text-gray-900 font-medium"><%= format_value(event.new_value) %></code>
                          </div>
                        </div>
                      </div>
                    </div>

                    <div class="text-right text-xs text-gray-400">
                      <%= format_time(event.timestamp) %>
                    </div>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>

        <!-- Help Section -->
        <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">💡 How Time-Travel Works</h3>
          <ul class="space-y-2 text-sm text-gray-600">
            <li class="flex items-start gap-2">
              <span class="text-green-500">●</span>
              <span><strong>Live Mode:</strong> New events are recorded as skills communicate in real-time</span>
            </li>
            <li class="flex items-start gap-2">
              <span class="text-amber-500">●</span>
              <span><strong>Replay Mode:</strong> Step through history to see how values changed over time</span>
            </li>
            <li class="flex items-start gap-2">
              <span class="text-blue-500">●</span>
              <span><strong>Forward:</strong> Apply an event (sets the new value in the skill)</span>
            </li>
            <li class="flex items-start gap-2">
              <span class="text-red-500">●</span>
              <span><strong>Backward:</strong> Unapply an event (restores the old value)</span>
            </li>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  defp mode_class(:live), do: "bg-green-100 text-green-800"
  defp mode_class(:replay), do: "bg-amber-100 text-amber-800"
  defp mode_class(_), do: "bg-gray-100 text-gray-800"

  defp format_value(value) when is_map(value), do: inspect(value, limit: 3)
  defp format_value(value) when is_list(value), do: "[#{length(value)} items]"
  defp format_value(nil), do: "nil"
  defp format_value(value), do: inspect(value)

  defp format_time(nil), do: "—"
  defp format_time(datetime) do
    Calendar.strftime(datetime, "%H:%M:%S")
  end
end
