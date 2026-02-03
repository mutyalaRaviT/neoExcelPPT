defmodule NeoExcelPPTWeb.SkillsLive do
  @moduledoc """
  LiveView for managing and inspecting Skills.

  Shows:
  - All running skills
  - Input/output channels for each skill
  - Current state of each skill
  - Communication graph between skills
  """
  use NeoExcelPPTWeb, :live_view

  alias NeoExcelPPT.Skills.{Registry, Channel, EventStore}

  import NeoExcelPPTWeb.CoreComponents

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Channel.subscribe(:event_store_updates)
    end

    skills = [
      %{
        name: :project_scope,
        module: "ProjectScopeSkill",
        description: "Calculates project scope metrics",
        input_channels: [:simple_files_count, :medium_files_count, :complex_files_count],
        output_channels: [:total_files, :simple_components, :medium_components, :complex_components, :project_scope_summary],
        status: :running,
        last_computed: DateTime.utc_now()
      },
      %{
        name: :component_scaler,
        module: "ComponentScalerSkill",
        description: "Scales component effort calculations",
        input_channels: [:simple_components, :medium_components, :complex_components],
        output_channels: [:scaling_summary, :total_base_days, :total_final_days],
        status: :running,
        last_computed: DateTime.utc_now()
      },
      %{
        name: :activity_calculator,
        module: "ActivityCalculatorSkill",
        description: "Calculates activity effort",
        input_channels: [:activity_updates, :team_assignment_updates],
        output_channels: [:activities_summary, :total_base_days, :total_final_days],
        status: :running,
        last_computed: DateTime.utc_now()
      },
      %{
        name: :effort_aggregator,
        module: "EffortAggregatorSkill",
        description: "Aggregates total effort",
        input_channels: [:total_base_days, :total_final_days],
        output_channels: [:effort_breakdown, :team_composition],
        status: :running,
        last_computed: DateTime.utc_now()
      },
      %{
        name: :buffer_calculator,
        module: "BufferCalculatorSkill",
        description: "Calculates project buffers",
        input_channels: [:total_final_days, :leave_buffer_pct, :dependency_buffer_pct],
        output_channels: [:proposed_buffers, :total_with_buffers],
        status: :running,
        last_computed: DateTime.utc_now()
      }
    ]

    socket =
      socket
      |> assign(:page_title, "Skills Management")
      |> assign(:skills, skills)
      |> assign(:selected_skill, nil)
      |> assign(:events, EventStore.get_events(limit: 20))

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    skill = Enum.find(socket.assigns.skills, &(to_string(&1.name) == id))
    {:noreply, assign(socket, :selected_skill, skill)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :selected_skill, nil)}
  end

  @impl true
  def handle_info({:channel_update, :event_store_updates, {:new_event, event}}, socket) do
    events = [event | socket.assigns.events] |> Enum.take(20)
    {:noreply, assign(socket, :events, events)}
  end

  @impl true
  def handle_info({:channel_update, _, _}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_skill", %{"name" => name}, socket) do
    skill = Enum.find(socket.assigns.skills, &(to_string(&1.name) == name))
    {:noreply, assign(socket, :selected_skill, skill)}
  end

  @impl true
  def handle_event("start_all_skills", _, socket) do
    Registry.init_project_skills()
    {:noreply, put_flash(socket, :info, "All skills started")}
  end

  @impl true
  def handle_event("stop_all_skills", _, socket) do
    Registry.stop_all_skills()
    {:noreply, put_flash(socket, :info, "All skills stopped")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Header Actions -->
      <div class="flex justify-between items-center">
        <h1 class="text-2xl font-bold text-gray-900">Skills Registry</h1>
        <div class="flex gap-2">
          <.button variant="primary" phx-click="start_all_skills">
            Start All Skills
          </.button>
          <.button variant="secondary" phx-click="stop_all_skills">
            Stop All
          </.button>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- Skills List -->
        <div class="lg:col-span-2">
          <.card>
            <.card_header icon="🎯" title="Active Skills" />
            <div class="divide-y divide-gray-100">
              <%= for skill <- @skills do %>
                <div
                  class={"p-4 cursor-pointer hover:bg-gray-50 #{if @selected_skill && @selected_skill.name == skill.name, do: "bg-blue-50", else: ""}"}
                  phx-click="select_skill"
                  phx-value-name={skill.name}
                >
                  <div class="flex items-start justify-between">
                    <div>
                      <div class="flex items-center gap-2">
                        <span class={"w-2 h-2 rounded-full #{status_color(skill.status)}"}></span>
                        <h3 class="font-semibold text-gray-900"><%= skill.module %></h3>
                        <.badge color="blue"><%= skill.name %></.badge>
                      </div>
                      <p class="text-sm text-gray-500 mt-1"><%= skill.description %></p>
                    </div>
                    <span class="text-xs text-gray-400">
                      <%= format_time(skill.last_computed) %>
                    </span>
                  </div>

                  <div class="mt-3 flex gap-4 text-xs">
                    <div>
                      <span class="text-gray-500">Inputs:</span>
                      <div class="flex flex-wrap gap-1 mt-1">
                        <%= for ch <- skill.input_channels do %>
                          <span class="px-2 py-0.5 bg-green-100 text-green-700 rounded">
                            <%= ch %>
                          </span>
                        <% end %>
                      </div>
                    </div>
                    <div>
                      <span class="text-gray-500">Outputs:</span>
                      <div class="flex flex-wrap gap-1 mt-1">
                        <%= for ch <- skill.output_channels do %>
                          <span class="px-2 py-0.5 bg-blue-100 text-blue-700 rounded">
                            <%= ch %>
                          </span>
                        <% end %>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          </.card>
        </div>

        <!-- Skill Details / Communication Graph -->
        <div>
          <%= if @selected_skill do %>
            <.card>
              <.card_header icon="🔍" title={"#{@selected_skill.module} Details"} />
              <div class="p-4 space-y-4">
                <div>
                  <h4 class="text-sm font-medium text-gray-500 mb-2">Status</h4>
                  <div class="flex items-center gap-2">
                    <span class={"w-3 h-3 rounded-full #{status_color(@selected_skill.status)}"}></span>
                    <span class="capitalize"><%= @selected_skill.status %></span>
                  </div>
                </div>

                <div>
                  <h4 class="text-sm font-medium text-gray-500 mb-2">Input Channels</h4>
                  <div class="space-y-1">
                    <%= for ch <- @selected_skill.input_channels do %>
                      <div class="flex items-center gap-2 text-sm">
                        <span class="text-green-500">→</span>
                        <code class="px-2 py-1 bg-gray-100 rounded"><%= ch %></code>
                      </div>
                    <% end %>
                  </div>
                </div>

                <div>
                  <h4 class="text-sm font-medium text-gray-500 mb-2">Output Channels</h4>
                  <div class="space-y-1">
                    <%= for ch <- @selected_skill.output_channels do %>
                      <div class="flex items-center gap-2 text-sm">
                        <span class="text-blue-500">←</span>
                        <code class="px-2 py-1 bg-gray-100 rounded"><%= ch %></code>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            </.card>
          <% else %>
            <.card>
              <.card_header icon="🔗" title="Communication Graph" />
              <div class="p-4">
                <div class="text-center text-gray-500 py-8">
                  <p>Select a skill to see details</p>
                  <p class="text-sm mt-2">or view the communication graph</p>
                </div>

                <!-- Simple ASCII-style graph -->
                <div class="mt-4 p-4 bg-gray-900 rounded-lg text-green-400 font-mono text-xs overflow-x-auto">
                  <pre>
┌─────────────────┐
│  ProjectScope   │
└────────┬────────┘
         │
    ┌────▼────┐
    │ Channel │ :total_files
    └────┬────┘
         │
┌────────▼────────┐
│ ComponentScaler │
└────────┬────────┘
         │
    ┌────▼────┐
    │ Channel │ :total_base_days
    └────┬────┘
         │
┌────────▼─────────┐
│ EffortAggregator │
└────────┬─────────┘
         │
    ┌────▼────┐
    │ Channel │ :total_final_days
    └────┬────┘
         │
┌────────▼─────────┐
│ BufferCalculator │
└──────────────────┘
                  </pre>
                </div>
              </div>
            </.card>
          <% end %>

          <!-- Recent Events -->
          <.card class="mt-6">
            <.card_header icon="📜" title="Recent Events" />
            <div class="divide-y divide-gray-100 max-h-80 overflow-y-auto">
              <%= for event <- @events do %>
                <div class="p-3 text-sm">
                  <div class="flex items-center gap-2">
                    <span class="text-blue-500">●</span>
                    <span class="font-medium"><%= event.skill %></span>
                    <span class="text-gray-400">→</span>
                    <code class="text-xs bg-gray-100 px-1 rounded"><%= event.channel %></code>
                  </div>
                  <div class="ml-4 mt-1 text-gray-500 text-xs">
                    <%= inspect(event.old_value) %> → <%= inspect(event.new_value) %>
                  </div>
                </div>
              <% end %>
              <%= if @events == [] do %>
                <div class="p-4 text-center text-gray-500">
                  No events recorded yet
                </div>
              <% end %>
            </div>
          </.card>
        </div>
      </div>
    </div>
    """
  end

  defp status_color(:running), do: "bg-green-500"
  defp status_color(:stopped), do: "bg-gray-400"
  defp status_color(:error), do: "bg-red-500"
  defp status_color(_), do: "bg-yellow-500"

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%H:%M:%S")
  end
end
