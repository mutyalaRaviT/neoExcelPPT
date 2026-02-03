defmodule NeoExcelPPTWeb.ProjectLive do
  @moduledoc """
  Main project estimation LiveView.

  Displays:
  - Project Scope section
  - Main Activities & Responsibilities table
  - Component Scaling Calculator
  - Project Details (Effort Breakdown, Buffers, Team Composition)

  Subscribes to skill output channels for real-time updates.
  """
  use NeoExcelPPTWeb, :live_view

  alias NeoExcelPPT.Skills.{Channel, Registry, EventStore}
  alias NeoExcelPPTWeb.Components.{ProjectScope, ActivitiesTable, ComponentScaling, ProjectDetails}

  import NeoExcelPPTWeb.CoreComponents

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to skill output channels
      Channel.subscribe(:project_scope_summary)
      Channel.subscribe(:activities_summary)
      Channel.subscribe(:scaling_summary)
      Channel.subscribe(:effort_breakdown)
      Channel.subscribe(:proposed_buffers)
      Channel.subscribe(:team_composition)
      Channel.subscribe(:event_store_updates)

      # Initialize skills if not already running
      unless Registry.skill_running?(:project_scope) do
        Registry.init_project_skills()
      end
    end

    socket =
      socket
      |> assign(:page_title, "Project Estimation")
      |> assign(:project_scope, default_project_scope())
      |> assign(:activities, default_activities())
      |> assign(:scaling, default_scaling())
      |> assign(:effort, default_effort())
      |> assign(:buffers, default_buffers())
      |> assign(:team, default_team())
      |> assign(:show_team_assignments, true)
      |> assign(:show_detailed_hours, false)
      |> assign(:show_summary_columns, true)
      |> assign(:recent_events, [])

    {:ok, socket}
  end

  @impl true
  def handle_info({:channel_update, :project_scope_summary, value}, socket) do
    {:noreply, assign(socket, :project_scope, value)}
  end

  @impl true
  def handle_info({:channel_update, :activities_summary, value}, socket) do
    {:noreply, assign(socket, :activities, value)}
  end

  @impl true
  def handle_info({:channel_update, :scaling_summary, value}, socket) do
    {:noreply, assign(socket, :scaling, value)}
  end

  @impl true
  def handle_info({:channel_update, :effort_breakdown, value}, socket) do
    {:noreply, assign(socket, :effort, value)}
  end

  @impl true
  def handle_info({:channel_update, :proposed_buffers, value}, socket) do
    {:noreply, assign(socket, :buffers, value)}
  end

  @impl true
  def handle_info({:channel_update, :team_composition, value}, socket) do
    {:noreply, assign(socket, :team, value)}
  end

  @impl true
  def handle_info({:channel_update, :event_store_updates, {:new_event, event}}, socket) do
    recent = [event | socket.assigns.recent_events] |> Enum.take(5)
    {:noreply, assign(socket, :recent_events, recent)}
  end

  @impl true
  def handle_info({:channel_update, _, _}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_team_assignments", _, socket) do
    {:noreply, update(socket, :show_team_assignments, &(!&1))}
  end

  @impl true
  def handle_event("toggle_detailed_hours", _, socket) do
    {:noreply, update(socket, :show_detailed_hours, &(!&1))}
  end

  @impl true
  def handle_event("toggle_summary_columns", _, socket) do
    {:noreply, update(socket, :show_summary_columns, &(!&1))}
  end

  @impl true
  def handle_event("update_file_count", %{"type" => type, "value" => value}, socket) do
    channel = String.to_atom("#{type}_files_count")
    {count, _} = Integer.parse(value)
    Channel.publish(channel, count)
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_activity", %{"id" => id, "field" => field, "value" => value}, socket) do
    Channel.publish(:activity_updates, %{id: id, field: field, value: value})
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Project Scope Section -->
      <.card>
        <.card_header icon="⚙️" title="Project Scope" />
        <div class="p-6">
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
            <!-- Left side: Basic info -->
            <div class="space-y-6">
              <div class="flex justify-between items-center">
                <span class="text-gray-600">Total Files</span>
                <span class="text-2xl font-mono font-bold text-blue-600">
                  <%= format_number(@project_scope.total_files) %>
                </span>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-gray-600">Project Type</span>
                <span class="text-lg font-semibold text-green-600">
                  <%= @project_scope.project_type %>
                </span>
              </div>
              <div class="mt-6">
                <h4 class="font-medium text-gray-900 mb-3">Project Steps:</h4>
                <ul class="space-y-2 text-sm text-gray-600">
                  <li class="flex items-center gap-2">
                    <span class="text-green-500">◉</span>
                    Data migration and DDL availability
                  </li>
                  <li class="flex items-center gap-2">
                    <span class="text-green-500">◉</span>
                    Code extraction from ODI
                  </li>
                  <li class="flex items-center gap-2">
                    <span class="text-green-500">◉</span>
                    Code conversion to IDMC
                  </li>
                  <li class="flex items-center gap-2">
                    <span class="text-green-500">◉</span>
                    IDMC Mapping creation
                  </li>
                  <li class="flex items-center gap-2">
                    <span class="text-green-500">◉</span>
                    IDMC Mapping Execution
                  </li>
                  <li class="flex items-center gap-2">
                    <span class="text-green-500">◉</span>
                    Debugging and fixing issues
                  </li>
                  <li class="flex items-center gap-2">
                    <span class="text-green-500">◉</span>
                    SIT/PROD testing and maintenance
                  </li>
                </ul>
              </div>
            </div>

            <!-- Right side: Component breakdown -->
            <div>
              <h4 class="font-medium text-gray-900 mb-4">Component Breakdown</h4>
              <div class="space-y-3">
                <%= for item <- @project_scope.breakdown do %>
                  <div class={"p-4 rounded-lg border-l-4 #{complexity_border_color(item.type)}"}>
                    <div class="flex justify-between items-start">
                      <div>
                        <p class="font-medium text-gray-900">
                          <%= format_number(item.files) %> <%= complexity_label(item.type) %> files × <%= item.components_per %> components
                        </p>
                        <p class="text-sm text-gray-500"><%= item.label %></p>
                      </div>
                      <div class="text-right">
                        <p class="text-lg font-mono font-bold"><%= format_k(item.total_components) %></p>
                        <p class={"text-sm #{auto_color(item.auto_pct)}"}><%= item.auto_pct %>% auto</p>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
              <div class="mt-4 p-3 bg-gray-50 rounded-lg flex items-center gap-2">
                <span class="text-blue-500">ℹ️</span>
                <span class="text-sm text-gray-600">
                  <strong>Default Unit:</strong> 15 components = 1 day effort
                </span>
              </div>
            </div>
          </div>
        </div>
      </.card>

      <!-- Main Activities & Responsibilities -->
      <.card>
        <.card_header icon="📋" title="Main Activities & Responsibilities">
          <:actions>
            <button class="text-sm text-blue-600 hover:text-blue-800 flex items-center gap-1">
              <span>✏️</span> Edit
            </button>
          </:actions>
        </.card_header>
        <div class="p-4">
          <!-- Toggle controls -->
          <div class="flex gap-4 mb-4">
            <label class="flex items-center gap-2 cursor-pointer">
              <input
                type="checkbox"
                checked={@show_team_assignments}
                phx-click="toggle_team_assignments"
                class="rounded border-gray-300 text-blue-600"
              />
              <span class="text-sm text-gray-700">Team Assignments</span>
            </label>
            <label class="flex items-center gap-2 cursor-pointer">
              <input
                type="checkbox"
                checked={@show_detailed_hours}
                phx-click="toggle_detailed_hours"
                class="rounded border-gray-300 text-blue-600"
              />
              <span class="text-sm text-gray-700">Detailed Hours</span>
            </label>
            <label class="flex items-center gap-2 cursor-pointer">
              <input
                type="checkbox"
                checked={@show_summary_columns}
                phx-click="toggle_summary_columns"
                class="rounded border-gray-300 text-blue-600"
              />
              <span class="text-sm text-gray-700">Summary Columns</span>
            </label>
          </div>

          <!-- Activities Table -->
          <div class="overflow-x-auto">
            <table class="min-w-full">
              <thead>
                <tr class="border-b border-gray-200">
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Activity/Task</th>
                  <%= if @show_team_assignments do %>
                    <th class="px-3 py-3 text-center text-xs font-medium text-gray-500 uppercase" colspan="3">Team Assignments</th>
                  <% end %>
                  <th class="px-3 py-3 text-center text-xs font-medium text-gray-500 uppercase">Days/Unit</th>
                  <%= if @show_summary_columns do %>
                    <th class="px-3 py-3 text-center text-xs font-medium text-gray-500 uppercase bg-amber-50" colspan="3">Summary</th>
                  <% end %>
                </tr>
                <tr class="border-b border-gray-100">
                  <th></th>
                  <%= if @show_team_assignments do %>
                    <th class="px-3 py-2 text-center text-xs text-gray-400">SB</th>
                    <th class="px-3 py-2 text-center text-xs text-gray-400">CG</th>
                    <th class="px-3 py-2 text-center text-xs text-gray-400">S2P</th>
                  <% end %>
                  <th></th>
                  <%= if @show_summary_columns do %>
                    <th class="px-3 py-2 text-center text-xs text-gray-400 bg-amber-50">Auto %</th>
                    <th class="px-3 py-2 text-center text-xs text-gray-400 bg-amber-50">Total Base</th>
                    <th class="px-3 py-2 text-center text-xs text-gray-400 bg-amber-50">Total Final</th>
                  <% end %>
                </tr>
              </thead>
              <tbody>
                <%= for category <- @activities.categories do %>
                  <!-- Category Header Row -->
                  <tr class={"#{category_bg_color(category.category)}"}>
                    <td class="px-4 py-3">
                      <span class="flex items-center gap-2 font-semibold text-gray-900">
                        <span><%= category_icon(category.category) %></span>
                        <%= category_name(category.category) %>
                      </span>
                    </td>
                    <%= if @show_team_assignments do %>
                      <td class="px-3 py-3 text-center">
                        <.checkbox checked={false} />
                      </td>
                      <td class="px-3 py-3 text-center">
                        <.checkbox checked={false} />
                      </td>
                      <td class="px-3 py-3 text-center">
                        <.checkbox checked={true} />
                      </td>
                    <% end %>
                    <td class="px-3 py-3 text-center text-sm text-gray-600">&lt; 0.1</td>
                    <%= if @show_summary_columns do %>
                      <td class="px-3 py-3 text-center bg-amber-50">
                        <span class="text-green-600 font-medium"><%= category.auto_pct %>%</span>
                      </td>
                      <td class="px-3 py-3 text-center bg-amber-50">
                        <span class="font-semibold"><%= Float.round(category.total_base, 1) %> days</span>
                      </td>
                      <td class="px-3 py-3 text-center bg-amber-50">
                        <span class="text-green-600 font-medium"><%= Float.round(category.total_final, 1) %> days</span>
                      </td>
                    <% end %>
                  </tr>
                  <!-- Activity Rows -->
                  <%= for activity <- category.activities, !activity.is_category do %>
                    <tr class="border-b border-gray-100 hover:bg-gray-50">
                      <td class="px-4 py-3 pl-8">
                        <span class="text-gray-600 flex items-center gap-2">
                          <span class="text-gray-300">├──</span>
                          <%= activity.name %>
                        </span>
                      </td>
                      <%= if @show_team_assignments do %>
                        <td class="px-3 py-3 text-center">
                          <.checkbox checked={activity.team.sb} />
                        </td>
                        <td class="px-3 py-3 text-center">
                          <.checkbox checked={activity.team.cg} />
                        </td>
                        <td class="px-3 py-3 text-center">
                          <.checkbox checked={activity.team.s2p} />
                        </td>
                      <% end %>
                      <td class="px-3 py-3 text-center text-sm text-gray-600"><%= activity.days_unit %></td>
                      <%= if @show_summary_columns do %>
                        <td class="px-3 py-3 text-center bg-amber-50 text-sm"><%= activity.auto_pct %>%</td>
                        <td class="px-3 py-3 text-center bg-amber-50 text-sm"><%= activity.base_days %> days</td>
                        <td class="px-3 py-3 text-center bg-amber-50">
                          <span class="text-green-600 text-sm"><%= Float.round(activity.base_days * (1 - activity.auto_pct / 100), 1) %> days</span>
                        </td>
                      <% end %>
                    </tr>
                  <% end %>
                <% end %>
                <!-- Totals Row -->
                <tr class="bg-gray-100 font-semibold">
                  <td class="px-4 py-3">
                    <span class="flex items-center gap-2">
                      <span>📊</span> TOTALS
                    </span>
                  </td>
                  <%= if @show_team_assignments do %>
                    <td class="px-3 py-3 text-center"><.checkbox checked={false} /></td>
                    <td class="px-3 py-3 text-center"><.checkbox checked={false} /></td>
                    <td class="px-3 py-3 text-center"><.checkbox checked={false} /></td>
                  <% end %>
                  <td class="px-3 py-3 text-center text-sm">&lt; 0.1</td>
                  <%= if @show_summary_columns do %>
                    <td class="px-3 py-3 text-center bg-amber-50">
                      <span class="text-green-600"><%= @activities.totals.auto_pct %>%</span>
                    </td>
                    <td class="px-3 py-3 text-center bg-amber-50">
                      <span><%= Float.round(@activities.totals.base_days, 1) %> days</span>
                    </td>
                    <td class="px-3 py-3 text-center bg-amber-50">
                      <span class="text-green-600"><%= Float.round(@activities.totals.final_days, 1) %> days</span>
                    </td>
                  <% end %>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </.card>

      <!-- Component Scaling Calculator -->
      <.card>
        <.card_header icon="📐" title="Component Scaling Calculator" />
        <div class="p-4">
          <div class="overflow-x-auto">
            <table class="min-w-full">
              <thead>
                <tr class="bg-blue-50">
                  <th class="px-4 py-3 text-left text-xs font-medium text-blue-700 uppercase">Component Type</th>
                  <th class="px-4 py-3 text-center text-xs font-medium text-blue-700 uppercase">Count</th>
                  <th class="px-4 py-3 text-center text-xs font-medium text-blue-700 uppercase">Avg Units</th>
                  <th class="px-4 py-3 text-center text-xs font-medium text-blue-700 uppercase">Total Units</th>
                  <th class="px-4 py-3 text-center text-xs font-medium text-blue-700 uppercase">Time/Unit</th>
                  <th class="px-4 py-3 text-center text-xs font-medium text-blue-700 uppercase">Base Days</th>
                  <th class="px-4 py-3 text-center text-xs font-medium text-blue-700 uppercase">Auto %</th>
                  <th class="px-4 py-3 text-center text-xs font-medium text-blue-700 uppercase">Final Days</th>
                </tr>
              </thead>
              <tbody>
                <%= for row <- @scaling.rows do %>
                  <tr class="border-b border-gray-100 hover:bg-gray-50">
                    <td class={"px-4 py-3 font-medium #{scaling_type_color(row.type)}"}>
                      <%= row.type %>
                    </td>
                    <td class="px-4 py-3 text-center">
                      <input
                        type="number"
                        value={row.count}
                        class="w-20 text-center border-gray-200 rounded text-sm"
                      />
                    </td>
                    <td class="px-4 py-3 text-center">
                      <input
                        type="number"
                        value={row.avg_units}
                        class="w-16 text-center border-gray-200 rounded text-sm"
                      />
                    </td>
                    <td class="px-4 py-3 text-center font-mono"><%= format_k(row.total_units) %></td>
                    <td class="px-4 py-3 text-center">
                      <input
                        type="number"
                        value={row.time_per_unit}
                        step="0.01"
                        class="w-16 text-center border-gray-200 rounded text-sm"
                      />
                    </td>
                    <td class="px-4 py-3 text-center font-mono"><%= format_number(trunc(row.base_days)) %> days</td>
                    <td class="px-4 py-3 text-center">
                      <input
                        type="number"
                        value={row.auto_pct}
                        class="w-16 text-center border-gray-200 rounded text-sm"
                      />
                    </td>
                    <td class="px-4 py-3 text-center font-mono"><%= format_number(trunc(row.final_days)) %> days</td>
                  </tr>
                <% end %>
                <tr class="bg-gray-800 text-white font-semibold">
                  <td class="px-4 py-3">TOTAL SCALED EFFORT:</td>
                  <td class="px-4 py-3 text-center">—</td>
                  <td class="px-4 py-3 text-center"><%= Float.round(@scaling.totals.total_units / length(@scaling.rows), 1) %></td>
                  <td class="px-4 py-3 text-center font-mono"><%= format_k(@scaling.totals.total_units) %></td>
                  <td class="px-4 py-3 text-center">—</td>
                  <td class="px-4 py-3 text-center font-mono"><%= format_number(trunc(@scaling.totals.total_base_days)) %> days</td>
                  <td class="px-4 py-3 text-center"><%= @scaling.totals.avg_auto_pct %>%</td>
                  <td class="px-4 py-3 text-center font-mono"><%= format_number(trunc(@scaling.totals.total_final_days)) %>h</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </.card>

      <!-- Project Details -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <!-- Effort Breakdown -->
        <.card>
          <.card_header icon="📊" title="Effort Breakdown" />
          <div class="p-6 space-y-4">
            <div>
              <p class="text-sm text-gray-500">Base Manual Days:</p>
              <p class="text-3xl font-mono font-bold text-orange-500">
                <%= Float.round(@effort.base_manual_days, 1) %> <span class="text-lg">days</span>
              </p>
            </div>
            <div>
              <p class="text-sm text-gray-500">Base Automation Days:</p>
              <p class="text-3xl font-mono font-bold text-orange-500">
                <%= Float.round(@effort.base_automation_days, 1) %> <span class="text-lg">days</span>
              </p>
            </div>
            <div>
              <p class="text-sm text-gray-500">Total Base Days:</p>
              <p class="text-3xl font-mono font-bold text-orange-500">
                <%= format_number(trunc(@effort.total_base_days)) %><span class="text-lg">h</span>
              </p>
            </div>
          </div>
        </.card>

        <!-- Proposed Buffers -->
        <.card>
          <.card_header icon="⏱️" title="Proposed Buffers" />
          <div class="p-6">
            <table class="w-full text-sm">
              <thead>
                <tr class="text-gray-500">
                  <th class="text-left pb-2">Buffer Type</th>
                  <th class="text-center pb-2">%</th>
                  <th class="text-right pb-2">Hours</th>
                </tr>
              </thead>
              <tbody>
                <%= for buffer <- @buffers.buffers do %>
                  <tr class="border-t border-gray-100">
                    <td class="py-2">
                      <p class="font-medium"><%= buffer.type %></p>
                      <p class="text-xs text-gray-400"><%= buffer.description %></p>
                    </td>
                    <td class="py-2 text-center"><%= buffer.percentage %>%</td>
                    <td class="py-2 text-right font-mono"><%= buffer.days %> days</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </.card>

        <!-- Team Composition -->
        <.card>
          <.card_header icon="👥" title="Team Composition" />
          <div class="p-6 space-y-4">
            <div class="flex justify-between items-center">
              <span class="text-gray-600">Automation Team:</span>
              <span class="text-4xl font-bold text-blue-600"><%= @team.automation_team %></span>
            </div>
            <div class="flex justify-between items-center">
              <span class="text-gray-600">Testing Team:</span>
              <span class="text-4xl font-bold text-orange-500"><%= @team.testing_team %></span>
            </div>
            <div class="border-t pt-4">
              <div class="flex justify-between items-center">
                <span class="text-gray-600">Total Resources:</span>
                <span class="text-2xl font-bold text-gray-900"><%= @team.total_resources %></span>
              </div>
            </div>
          </div>
        </.card>
      </div>

      <!-- Recent Events (if any) -->
      <%= if @recent_events != [] do %>
        <.card>
          <.card_header icon="🔔" title="Recent Changes" />
          <div class="p-4">
            <div class="space-y-2">
              <%= for event <- @recent_events do %>
                <div class="flex items-center gap-3 text-sm p-2 bg-blue-50 rounded">
                  <span class="text-blue-500">●</span>
                  <span class="font-medium"><%= event.skill %></span>
                  <span class="text-gray-400">→</span>
                  <span><%= event.channel %></span>
                  <span class="text-gray-400">changed to</span>
                  <span class="font-mono"><%= inspect(event.new_value) %></span>
                </div>
              <% end %>
            </div>
          </div>
        </.card>
      <% end %>
    </div>
    """
  end

  # Helper functions

  defp format_number(num) when is_integer(num) do
    num
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  defp format_number(num), do: format_number(trunc(num))

  defp format_k(num) when num >= 1000 do
    "#{Float.round(num / 1000, 1)}k"
  end

  defp format_k(num), do: "#{num}"

  defp complexity_border_color(:simple), do: "border-green-400 bg-green-50"
  defp complexity_border_color(:medium), do: "border-yellow-400 bg-yellow-50"
  defp complexity_border_color(:complex), do: "border-orange-400 bg-orange-50"

  defp complexity_label(:simple), do: "simple"
  defp complexity_label(:medium), do: "medium"
  defp complexity_label(:complex), do: "complex"

  defp auto_color(pct) when pct >= 80, do: "text-green-600"
  defp auto_color(pct) when pct >= 60, do: "text-yellow-600"
  defp auto_color(_), do: "text-orange-600"

  defp category_bg_color(:preprocessing), do: "bg-yellow-50"
  defp category_bg_color(:code_conversion), do: "bg-blue-50"
  defp category_bg_color(:execution_with_data), do: "bg-purple-50"
  defp category_bg_color(:post_processing), do: "bg-green-50"
  defp category_bg_color(_), do: "bg-gray-50"

  defp category_icon(:preprocessing), do: "📁"
  defp category_icon(:code_conversion), do: "💻"
  defp category_icon(:execution_with_data), do: "⚡"
  defp category_icon(:post_processing), do: "🚀"
  defp category_icon(_), do: "📋"

  defp category_name(:preprocessing), do: "PREPROCESSING"
  defp category_name(:code_conversion), do: "CODE CONVERSION"
  defp category_name(:execution_with_data), do: "EXECUTION WITH DATA"
  defp category_name(:post_processing), do: "POST PROCESSING"
  defp category_name(cat), do: cat |> to_string() |> String.upcase()

  defp scaling_type_color("Simple files"), do: "text-green-600"
  defp scaling_type_color("Medium files"), do: "text-yellow-600"
  defp scaling_type_color("Complex files"), do: "text-orange-600"
  defp scaling_type_color(_), do: "text-gray-600"

  # Default data functions

  defp default_project_scope do
    %{
      total_files: 55_220,
      project_type: "ODI → IDMC",
      breakdown: [
        %{type: :simple, files: 55_000, components_per: 15, total_components: 825_000, auto_pct: 90, label: "Basic transformations"},
        %{type: :medium, files: 110, components_per: 150, total_components: 16_500, auto_pct: 75, label: "Moderate complexity"},
        %{type: :complex, files: 110, components_per: 300, total_components: 33_000, auto_pct: 65, label: "Advanced processing"}
      ]
    }
  end

  defp default_activities do
    %{
      categories: [
        %{
          category: :preprocessing,
          auto_pct: 90,
          total_base: 15.0,
          total_final: 1.5,
          activities: [
            %{id: "prep", name: "PREPROCESSING", is_category: true, team: %{sb: false, cg: false, s2p: true}, days_unit: 0.1, auto_pct: 90, base_days: 15},
            %{id: "ddls", name: "DDLs Ready", is_category: false, team: %{sb: false, cg: false, s2p: true}, days_unit: 0.3, auto_pct: 95, base_days: 3},
            %{id: "data", name: "Data Ready", is_category: false, team: %{sb: true, cg: false, s2p: false}, days_unit: 0.6, auto_pct: 80, base_days: 6},
            %{id: "flow", name: "Mapping Flow ID", is_category: false, team: %{sb: false, cg: true, s2p: false}, days_unit: 0.1, auto_pct: 85, base_days: 6}
          ]
        },
        %{
          category: :code_conversion,
          auto_pct: 85,
          total_base: 30.0,
          total_final: 4.5,
          activities: [
            %{id: "cc", name: "CODE CONVERSION", is_category: true, team: %{sb: false, cg: false, s2p: true}, days_unit: 0.1, auto_pct: 85, base_days: 30},
            %{id: "mc", name: "Mapping Creation", is_category: false, team: %{sb: false, cg: false, s2p: true}, days_unit: 0.1, auto_pct: 90, base_days: 15},
            %{id: "ce", name: "Code Execution", is_category: false, team: %{sb: false, cg: false, s2p: true}, days_unit: 0.1, auto_pct: 70, base_days: 15},
            %{id: "cv", name: "Compile Validation", is_category: false, team: %{sb: false, cg: true, s2p: false}, days_unit: 0.1, auto_pct: 60, base_days: 6}
          ]
        },
        %{
          category: :execution_with_data,
          auto_pct: 65,
          total_base: 22.5,
          total_final: 7.9,
          activities: [
            %{id: "ed", name: "EXECUTION WITH DATA", is_category: true, team: %{sb: false, cg: true, s2p: false}, days_unit: 0.1, auto_pct: 65, base_days: 22.5},
            %{id: "dv", name: "Data Verification", is_category: false, team: %{sb: false, cg: true, s2p: false}, days_unit: 0.1, auto_pct: 70, base_days: 7.5},
            %{id: "ex", name: "Execute", is_category: false, team: %{sb: true, cg: false, s2p: false}, days_unit: 0.1, auto_pct: 95, base_days: 3.8},
            %{id: "vl", name: "Validation & Logs", is_category: false, team: %{sb: false, cg: false, s2p: true}, days_unit: 0.1, auto_pct: 50, base_days: 7.5},
            %{id: "dd", name: "Debug Data Issues", is_category: false, team: %{sb: false, cg: true, s2p: false}, days_unit: 0.1, auto_pct: 40, base_days: 3.8},
            %{id: "dc", name: "Debug Code Issues", is_category: false, team: %{sb: false, cg: true, s2p: false}, days_unit: 0.1, auto_pct: 30, base_days: 3}
          ]
        },
        %{
          category: :post_processing,
          auto_pct: 75,
          total_base: 15.0,
          total_final: 3.8,
          activities: [
            %{id: "pp", name: "POST PROCESSING", is_category: true, team: %{sb: true, cg: true, s2p: false}, days_unit: 0.1, auto_pct: 75, base_days: 15},
            %{id: "ds", name: "Dev to SIT Movement", is_category: false, team: %{sb: true, cg: true, s2p: false}, days_unit: 0.1, auto_pct: 80, base_days: 6},
            %{id: "it", name: "Integration Testing", is_category: false, team: %{sb: false, cg: true, s2p: false}, days_unit: 0.1, auto_pct: 70, base_days: 6},
            %{id: "dm", name: "Deployment & Maintenance", is_category: false, team: %{sb: true, cg: false, s2p: false}, days_unit: 0.1, auto_pct: 60, base_days: 3}
          ]
        }
      ],
      totals: %{
        auto_pct: 76,
        base_days: 82.5,
        final_days: 19.8
      }
    }
  end

  defp default_scaling do
    %{
      rows: [
        %{type: "Simple files", count: 55_000, avg_units: 15, total_units: 825_000, time_per_unit: 0.16, base_days: 132_000, auto_pct: 90, final_days: 13_200},
        %{type: "Medium files", count: 110, avg_units: 150, total_units: 16_500, time_per_unit: 2.16, base_days: 35_877, auto_pct: 75, final_days: 8_969},
        %{type: "Complex files", count: 110, avg_units: 300, total_units: 33_000, time_per_unit: 4.32, base_days: 142_560, auto_pct: 65, final_days: 49_896}
      ],
      totals: %{
        total_units: 874_500,
        total_base_days: 310_437,
        avg_auto_pct: 76.8,
        total_final_days: 503
      }
    }
  end

  defp default_effort do
    %{
      base_manual_days: 62.8,
      base_automation_days: 193.7,
      total_base_days: 660
    }
  end

  defp default_buffers do
    %{
      buffers: [
        %{type: "Leave Buffer", percentage: 15, days: 9.4, description: "Sick leaves, personal time, holidays, unplanned absenteeism"},
        %{type: "Dependency Buffer", percentage: 10, days: 6.3, description: "Delays from external teams or systems"},
        %{type: "Learning Curve Buffer", percentage: 15, days: 9.4, description: "Onboarding and skill development time"}
      ],
      total_buffer_days: 25.1,
      total_buffer_pct: 40
    }
  end

  defp default_team do
    %{
      automation_team: 6,
      testing_team: 6,
      total_resources: 12
    }
  end
end
