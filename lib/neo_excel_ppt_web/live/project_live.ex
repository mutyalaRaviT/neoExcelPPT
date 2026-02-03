defmodule NeoExcelPPTWeb.ProjectLive do
  @moduledoc """
  Main Project Estimation LiveView.

  Renders all skill components and handles real-time updates.
  All elements have proper IDs for Puppeteer/Playwright testing.
  """

  use NeoExcelPPTWeb, :live_view

  alias NeoExcelPPT.Skills.{Channel, SkillManager, HistoryTracker}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to global events for live updates
      Channel.subscribe(:_global_events)
      Channel.subscribe(:total_files)
      Channel.subscribe(:component_breakdown)
      Channel.subscribe(:activity_totals)
      Channel.subscribe(:total_days)
      Channel.subscribe(:buffer_days)
    end

    # Get initial state from skills
    project_scope = get_skill_state(:project_scope)
    activities = get_skill_state(:activity_calculator)
    components = get_skill_state(:component_calculator)
    effort = get_skill_state(:effort_aggregator)
    buffers = get_skill_state(:buffer_calculator)

    socket =
      socket
      |> assign(:page_title, "Project Estimation")
      |> assign(:project_scope, project_scope)
      |> assign(:activities, activities)
      |> assign(:components, components)
      |> assign(:effort, effort)
      |> assign(:buffers, buffers)
      |> assign(:show_team_assignments, true)
      |> assign(:show_detailed_hours, false)
      |> assign(:show_summary_columns, true)

    {:ok, socket}
  end

  @impl true
  def handle_info({:channel_message, channel, message}, socket) do
    socket = case channel do
      :total_files ->
        assign(socket, :project_scope, Map.put(socket.assigns.project_scope, :total_files, message.data))

      :component_breakdown ->
        assign(socket, :project_scope, Map.put(socket.assigns.project_scope, :component_breakdown, message.data))

      :activity_totals ->
        assign(socket, :activities, Map.merge(socket.assigns.activities, message.data))

      :total_days ->
        assign(socket, :effort, Map.merge(socket.assigns.effort, message.data))

      :buffer_days ->
        assign(socket, :buffers, Map.merge(socket.assigns.buffers, message.data))

      :_global_events ->
        # Force refresh on any event
        socket

      _ ->
        socket
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_file_count", %{"type" => type, "value" => value}, socket) do
    {count, _} = Integer.parse(value)
    field = String.to_atom(type)

    current = socket.assigns.project_scope
    new_counts = %{
      simple: if(field == :simple_files, do: count, else: current.simple_files),
      medium: if(field == :medium_files, do: count, else: current.medium_files),
      complex: if(field == :complex_files, do: count, else: current.complex_files)
    }

    SkillManager.send_input(:project_scope, :file_counts, new_counts)

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_assignment", %{"activity" => activity_id, "member" => member}, socket) do
    activity_atom = String.to_atom(activity_id)
    current_activities = socket.assigns.activities.activities

    # Find current assignment state
    current_assigned = get_assignment(current_activities, activity_atom, member)

    SkillManager.send_input(:activity_calculator, :team_assignment, %{
      activity_id: activity_atom,
      member: member,
      assigned: !current_assigned
    })

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_activity", %{"activity" => activity_id, "field" => field, "value" => value}, socket) do
    activity_atom = String.to_atom(activity_id)
    field_atom = String.to_atom(field)

    parsed_value = case field_atom do
      :auto_pct -> parse_number(value)
      :base_days -> parse_number(value)
      :days_per_unit -> parse_number(value)
      _ -> value
    end

    SkillManager.send_input(:activity_calculator, :activity_update, %{
      id: activity_atom,
      field: field_atom,
      value: parsed_value
    })

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_view", %{"view" => view}, socket) do
    field = String.to_atom("show_#{view}")
    current = Map.get(socket.assigns, field, false)
    {:noreply, assign(socket, field, !current)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="project-estimation" class="min-h-screen bg-gray-50 p-6">
      <div class="max-w-7xl mx-auto space-y-6">

        <!-- Project Scope Section -->
        <.project_scope_section scope={@project_scope} />

        <!-- Main Activities Section -->
        <.activities_section
          activities={@activities}
          show_team={@show_team_assignments}
          show_hours={@show_detailed_hours}
          show_summary={@show_summary_columns}
        />

        <!-- Component Scaling Calculator -->
        <.component_calculator_section components={@components} />

        <!-- Project Details Grid -->
        <.project_details_section effort={@effort} buffers={@buffers} />

      </div>
    </div>
    """
  end

  # Component: Project Scope Section
  defp project_scope_section(assigns) do
    ~H"""
    <div id="project-scope" class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
      <div class="flex items-center gap-2 mb-6">
        <span class="text-xl">⚙️</span>
        <h2 class="text-lg font-semibold text-gray-900">Project Scope</h2>
      </div>

      <div class="grid grid-cols-2 gap-8">
        <!-- Left Column: Basic Info -->
        <div class="space-y-4">
          <div class="flex justify-between items-center">
            <span class="text-gray-600">Total Files</span>
            <span id="project-scope-total-files" class="text-2xl font-bold text-blue-600 font-mono">
              <%= format_number(@scope.total_files) %>
            </span>
          </div>

          <div class="flex justify-between items-center">
            <span class="text-gray-600">Project Type</span>
            <span id="project-scope-project-type" class="px-3 py-1 bg-green-100 text-green-700 rounded-full text-sm font-medium">
              <%= @scope.project_type %>
            </span>
          </div>

          <div class="mt-6">
            <h3 class="text-sm font-medium text-gray-700 mb-2">Project Steps:</h3>
            <ul class="space-y-1 text-sm text-gray-600">
              <li class="flex items-center gap-2">
                <span class="w-4 h-4 rounded-full border-2 border-green-500"></span>
                Data migration and DDL availability
              </li>
              <li class="flex items-center gap-2">
                <span class="w-4 h-4 rounded-full border-2 border-green-500"></span>
                Code extraction from ODI
              </li>
              <li class="flex items-center gap-2">
                <span class="w-4 h-4 rounded-full border-2 border-green-500"></span>
                Code conversion to IDMC
              </li>
              <li class="flex items-center gap-2">
                <span class="w-4 h-4 rounded-full border-2 border-green-500"></span>
                IDMC Mapping creation
              </li>
              <li class="flex items-center gap-2">
                <span class="w-4 h-4 rounded-full border-2 border-green-500"></span>
                Debugging and fixing issues
              </li>
            </ul>
          </div>
        </div>

        <!-- Right Column: Component Breakdown -->
        <div>
          <h3 class="text-sm font-medium text-gray-700 mb-4">Component Breakdown</h3>
          <div class="space-y-3">
            <!-- Simple Files -->
            <div id="component-simple" class="flex items-center justify-between p-3 bg-blue-50 rounded-lg border-l-4 border-blue-500">
              <div>
                <div class="flex items-center gap-2">
                  <input
                    id="project-scope-simple-count"
                    type="number"
                    value={@scope.simple_files}
                    phx-blur="update_file_count"
                    phx-value-type="simple_files"
                    class="w-24 px-2 py-1 border rounded text-sm font-mono"
                  />
                  <span class="text-sm text-gray-600">simple files × 15 components</span>
                </div>
                <p class="text-xs text-gray-500 mt-1">Basic transformations</p>
              </div>
              <div class="text-right">
                <span id="component-simple-total" class="text-lg font-bold text-gray-900 font-mono">
                  <%= format_number(@scope.component_breakdown.simple) %>
                </span>
                <p class="text-xs text-green-600">(90% auto)</p>
              </div>
            </div>

            <!-- Medium Files -->
            <div id="component-medium" class="flex items-center justify-between p-3 bg-yellow-50 rounded-lg border-l-4 border-yellow-500">
              <div>
                <div class="flex items-center gap-2">
                  <input
                    id="project-scope-medium-count"
                    type="number"
                    value={@scope.medium_files}
                    phx-blur="update_file_count"
                    phx-value-type="medium_files"
                    class="w-24 px-2 py-1 border rounded text-sm font-mono"
                  />
                  <span class="text-sm text-gray-600">medium files × 150 components</span>
                </div>
                <p class="text-xs text-gray-500 mt-1">Moderate complexity</p>
              </div>
              <div class="text-right">
                <span id="component-medium-total" class="text-lg font-bold text-gray-900 font-mono">
                  <%= format_number(@scope.component_breakdown.medium) %>
                </span>
                <p class="text-xs text-yellow-600">(75% auto)</p>
              </div>
            </div>

            <!-- Complex Files -->
            <div id="component-complex" class="flex items-center justify-between p-3 bg-orange-50 rounded-lg border-l-4 border-orange-500">
              <div>
                <div class="flex items-center gap-2">
                  <input
                    id="project-scope-complex-count"
                    type="number"
                    value={@scope.complex_files}
                    phx-blur="update_file_count"
                    phx-value-type="complex_files"
                    class="w-24 px-2 py-1 border rounded text-sm font-mono"
                  />
                  <span class="text-sm text-gray-600">complex files × 300 components</span>
                </div>
                <p class="text-xs text-gray-500 mt-1">Advanced processing</p>
              </div>
              <div class="text-right">
                <span id="component-complex-total" class="text-lg font-bold text-gray-900 font-mono">
                  <%= format_number(@scope.component_breakdown.complex) %>
                </span>
                <p class="text-xs text-orange-600">(65% auto)</p>
              </div>
            </div>

            <!-- Info -->
            <div class="flex items-center gap-2 text-sm text-gray-500 mt-4 p-2 bg-gray-50 rounded">
              <span>ℹ️</span>
              <span><strong>Default Unit:</strong> 15 components = 1 day effort</span>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Component: Activities Section
  defp activities_section(assigns) do
    ~H"""
    <div id="activities-table" class="bg-white rounded-xl shadow-sm border border-gray-200">
      <div class="flex items-center justify-between p-4 border-b border-gray-100">
        <div class="flex items-center gap-2">
          <span class="text-xl">📋</span>
          <h2 class="text-lg font-semibold text-gray-900">Main Activities & Responsibilities</h2>
        </div>
        <div class="flex items-center gap-4">
          <!-- Toggle buttons -->
          <label class="flex items-center gap-2 cursor-pointer">
            <input
              type="checkbox"
              checked={@show_team}
              phx-click="toggle_view"
              phx-value-view="team_assignments"
              class="rounded border-gray-300"
            />
            <span class="text-sm text-gray-600">Team Assignments</span>
          </label>
          <label class="flex items-center gap-2 cursor-pointer">
            <input
              type="checkbox"
              checked={@show_hours}
              phx-click="toggle_view"
              phx-value-view="detailed_hours"
              class="rounded border-gray-300"
            />
            <span class="text-sm text-gray-600">Detailed Hours</span>
          </label>
          <label class="flex items-center gap-2 cursor-pointer">
            <input
              type="checkbox"
              checked={@show_summary}
              phx-click="toggle_view"
              phx-value-view="summary_columns"
              class="rounded border-gray-300"
            />
            <span class="text-sm text-gray-600">Summary Columns</span>
          </label>
          <button class="text-gray-500 hover:text-gray-700">
            ✏️ Edit
          </button>
        </div>
      </div>

      <div class="overflow-x-auto">
        <table class="w-full">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Activity/Task</th>
              <%= if @show_team do %>
                <th class="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase" colspan="3">Team Assignments</th>
              <% end %>
              <th class="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase">Days/Unit</th>
              <%= if @show_summary do %>
                <th class="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase">Auto %</th>
                <th class="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase">Total Base</th>
                <th class="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase">Total Final</th>
              <% end %>
            </tr>
            <%= if @show_team do %>
              <tr class="bg-gray-50 border-b">
                <th></th>
                <th class="px-2 py-1 text-center text-xs text-gray-400">SB</th>
                <th class="px-2 py-1 text-center text-xs text-gray-400">CG</th>
                <th class="px-2 py-1 text-center text-xs text-gray-400">S2P</th>
                <th></th>
                <%= if @show_summary do %>
                  <th></th>
                  <th></th>
                  <th></th>
                <% end %>
              </tr>
            <% end %>
          </thead>
          <tbody class="divide-y divide-gray-100">
            <%= for {_key, activity} <- @activities.activities do %>
              <.activity_row
                activity={activity}
                is_parent={true}
                show_team={@show_team}
                show_summary={@show_summary}
              />
              <%= for child <- activity.children do %>
                <.activity_row
                  activity={child}
                  is_parent={false}
                  show_team={@show_team}
                  show_summary={@show_summary}
                />
              <% end %>
            <% end %>

            <!-- Totals Row -->
            <tr id="activities-totals" class="bg-gray-100 font-semibold">
              <td class="px-4 py-3">
                <div class="flex items-center gap-2">
                  <span>📊</span>
                  <span>TOTALS</span>
                </div>
              </td>
              <%= if @show_team do %>
                <td></td><td></td><td></td>
              <% end %>
              <td class="px-4 py-3 text-center text-gray-500">< 0.1</td>
              <%= if @show_summary do %>
                <td id="activities-total-auto-pct" class="px-4 py-3 text-center text-green-600">
                  <%= @activities.totals.avg_auto_pct %>%
                </td>
                <td id="activities-total-base-days" class="px-4 py-3 text-center font-bold">
                  <%= @activities.totals.base_days %> days
                </td>
                <td id="activities-total-final-days" class="px-4 py-3 text-center text-green-600 font-bold">
                  <%= @activities.totals.final_days %> days
                </td>
              <% end %>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  # Component: Single Activity Row
  defp activity_row(assigns) do
    color_classes = case assigns.activity[:color] do
      "yellow" -> "bg-yellow-50"
      "blue" -> "bg-blue-50"
      "purple" -> "bg-purple-50"
      "green" -> "bg-green-50"
      _ -> ""
    end

    assigns = assign(assigns, :color_classes, color_classes)

    ~H"""
    <tr id={"activity-row-#{@activity.id}"} class={if @is_parent, do: @color_classes, else: ""}>
      <td class="px-4 py-3">
        <div class={"flex items-center gap-2 #{if !@is_parent, do: "pl-6"}"}>
          <%= if @is_parent do %>
            <span><%= @activity.icon %></span>
            <span class="font-semibold text-gray-900"><%= @activity.name %></span>
          <% else %>
            <span class="text-gray-400">├──</span>
            <span class="text-gray-700"><%= @activity.name %></span>
          <% end %>
        </div>
      </td>

      <%= if @show_team do %>
        <%= for member <- ["SB", "CG", "S2P"] do %>
          <td class="px-2 py-3 text-center">
            <button
              id={"activity-#{@activity.id}-assignment-#{member}"}
              phx-click="toggle_assignment"
              phx-value-activity={@activity.id}
              phx-value-member={member}
              class={"w-5 h-5 rounded border-2 flex items-center justify-center #{if @activity.assignments[member], do: "bg-blue-500 border-blue-500 text-white", else: "border-gray-300"}"}
            >
              <%= if @activity.assignments[member] do %>
                <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
                </svg>
              <% end %>
            </button>
          </td>
        <% end %>
      <% end %>

      <td id={"activity-#{@activity.id}-days"} class="px-4 py-3 text-center text-gray-600">
        <%= @activity.days_per_unit %>
      </td>

      <%= if @show_summary do %>
        <td id={"activity-#{@activity.id}-auto-pct"} class="px-4 py-3 text-center text-green-600">
          <%= @activity.auto_pct %>%
        </td>
        <td id={"activity-#{@activity.id}-total-base"} class="px-4 py-3 text-center">
          <%= @activity.base_days %> days
        </td>
        <td id={"activity-#{@activity.id}-total-final"} class="px-4 py-3 text-center text-green-600">
          <%= @activity.final_days %> days
        </td>
      <% end %>
    </tr>
    """
  end

  # Component: Component Calculator Section
  defp component_calculator_section(assigns) do
    ~H"""
    <div id="component-calculator" class="bg-white rounded-xl shadow-sm border border-gray-200">
      <div class="flex items-center gap-2 p-4 border-b border-gray-100">
        <span class="text-xl">📐</span>
        <h2 class="text-lg font-semibold text-gray-900">Component Scaling Calculator</h2>
      </div>

      <div class="overflow-x-auto">
        <table class="w-full">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Component Type</th>
              <th class="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase">Count</th>
              <th class="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase">Avg Units</th>
              <th class="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase">Total Units</th>
              <th class="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase">Time/Unit</th>
              <th class="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase">Base Days</th>
              <th class="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase">Auto %</th>
              <th class="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase">Final Days</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            <%= for {type, config} <- @components.components do %>
              <tr id={"component-calc-row-#{type}"}>
                <td class="px-4 py-3">
                  <span class={"font-medium #{type_color(type)}"}><%= String.capitalize(to_string(type)) %> files</span>
                </td>
                <td id={"component-#{type}-count"} class="px-4 py-3 text-center">
                  <input
                    type="number"
                    value={config.count}
                    class="w-20 px-2 py-1 border rounded text-center font-mono"
                    readonly
                  />
                </td>
                <td id={"component-#{type}-avg-units"} class="px-4 py-3 text-center">
                  <input
                    type="number"
                    value={config.avg_units}
                    class="w-16 px-2 py-1 border rounded text-center font-mono"
                    readonly
                  />
                </td>
                <td id={"component-#{type}-total-units"} class="px-4 py-3 text-center font-mono">
                  <%= format_number(@components.scaled_effort[type].total_units) %>
                </td>
                <td id={"component-#{type}-time-unit"} class="px-4 py-3 text-center font-mono">
                  <%= config.time_per_unit %>
                </td>
                <td id={"component-#{type}-base-days"} class="px-4 py-3 text-center font-mono">
                  <%= format_number(@components.scaled_effort[type].base_days) %> days
                </td>
                <td id={"component-#{type}-auto-pct"} class="px-4 py-3 text-center">
                  <input
                    type="number"
                    value={config.auto_pct}
                    class="w-14 px-2 py-1 border rounded text-center font-mono"
                    readonly
                  />
                </td>
                <td id={"component-#{type}-final-days"} class="px-4 py-3 text-center font-mono text-green-600 font-bold">
                  <%= format_number(@components.scaled_effort[type].final_days) %> days
                </td>
              </tr>
            <% end %>

            <!-- Totals -->
            <tr id="component-calc-totals" class="bg-gray-100 font-semibold">
              <td class="px-4 py-3">TOTAL SCALED EFFORT:</td>
              <td class="px-4 py-3 text-center">—</td>
              <td id="component-totals-avg-units" class="px-4 py-3 text-center font-mono">
                <%= Float.round(@components.totals.total_units / 55220, 2) %>
              </td>
              <td id="component-totals-total-units" class="px-4 py-3 text-center font-mono">
                <%= format_number(@components.totals.total_units) %>
              </td>
              <td class="px-4 py-3 text-center">—</td>
              <td id="component-totals-base-days" class="px-4 py-3 text-center font-mono">
                <%= format_number(@components.totals.base_days) %> days
              </td>
              <td id="component-totals-auto-pct" class="px-4 py-3 text-center">
                <%= @components.totals.avg_auto_pct %>%
              </td>
              <td id="component-totals-final-days" class="px-4 py-3 text-center text-green-600">
                <%= format_number(@components.totals.final_days) %>h
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  # Component: Project Details Section
  defp project_details_section(assigns) do
    ~H"""
    <div id="project-details" class="grid grid-cols-3 gap-6">
      <!-- Effort Breakdown -->
      <div id="effort-breakdown" class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
        <div class="flex items-center gap-2 mb-6">
          <span class="text-xl">📊</span>
          <h2 class="text-lg font-semibold text-gray-900">Effort Breakdown</h2>
        </div>

        <div class="space-y-4">
          <div>
            <p class="text-sm text-gray-500">Base Manual Days:</p>
            <p id="effort-manual-days" class="text-3xl font-bold text-orange-500 font-mono">
              <%= @effort.manual_days %> days
            </p>
          </div>
          <div>
            <p class="text-sm text-gray-500">Base Automation Days:</p>
            <p id="effort-automation-days" class="text-3xl font-bold text-orange-500 font-mono">
              <%= @effort.automation_days %> days
            </p>
          </div>
          <div>
            <p class="text-sm text-gray-500">Total Base Days:</p>
            <p id="effort-total-days" class="text-3xl font-bold text-orange-500 font-mono">
              <%= @effort.total_base_days %>h
            </p>
          </div>
        </div>
      </div>

      <!-- Proposed Buffers -->
      <div id="proposed-buffers" class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
        <div class="flex items-center gap-2 mb-6">
          <span class="text-xl">⏱️</span>
          <h2 class="text-lg font-semibold text-gray-900">Proposed Buffers</h2>
        </div>

        <table class="w-full text-sm">
          <thead>
            <tr class="text-gray-500 text-left">
              <th class="pb-2">Buffer Type</th>
              <th class="pb-2 text-center">%</th>
              <th class="pb-2 text-right">Hours</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            <tr id="buffer-leave">
              <td class="py-2">
                <p class="font-medium">Leave Buffer</p>
                <p class="text-xs text-gray-400"><%= @buffers.buffers.leave.description %></p>
              </td>
              <td class="py-2 text-center"><%= @buffers.buffers.leave.percentage %>%</td>
              <td id="buffer-leave-days" class="py-2 text-right font-mono"><%= @buffers.buffers.leave.days %> days</td>
            </tr>
            <tr id="buffer-dependency">
              <td class="py-2">
                <p class="font-medium">Dependency Buffer</p>
                <p class="text-xs text-gray-400"><%= @buffers.buffers.dependency.description %></p>
              </td>
              <td class="py-2 text-center"><%= @buffers.buffers.dependency.percentage %>%</td>
              <td id="buffer-dependency-days" class="py-2 text-right font-mono"><%= @buffers.buffers.dependency.days %> days</td>
            </tr>
            <tr id="buffer-learning">
              <td class="py-2">
                <p class="font-medium">Learning Curve Buffer</p>
                <p class="text-xs text-gray-400"><%= @buffers.buffers.learning.description %></p>
              </td>
              <td class="py-2 text-center"><%= @buffers.buffers.learning.percentage %>%</td>
              <td id="buffer-learning-days" class="py-2 text-right font-mono"><%= @buffers.buffers.learning.days %> days</td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Team Composition -->
      <div id="team-composition" class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
        <div class="flex items-center gap-2 mb-6">
          <span class="text-xl">👥</span>
          <h2 class="text-lg font-semibold text-gray-900">Team Composition</h2>
        </div>

        <div class="space-y-4">
          <div class="flex justify-between items-center">
            <span class="text-gray-600">Automation Team:</span>
            <span id="team-automation-count" class="text-3xl font-bold text-orange-500 font-mono">
              <%= @effort.team.automation %>
            </span>
          </div>
          <div class="flex justify-between items-center">
            <span class="text-gray-600">Testing Team:</span>
            <span id="team-testing-count" class="text-3xl font-bold text-orange-500 font-mono">
              <%= @effort.team.testing %>
            </span>
          </div>
          <div class="flex justify-between items-center border-t pt-4">
            <span class="text-gray-600 font-semibold">Total Resources:</span>
            <span id="team-total-count" class="text-3xl font-bold text-orange-500 font-mono">
              <%= @effort.team.total %>
            </span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions
  defp get_skill_state(skill_id) do
    case skill_id do
      :project_scope -> NeoExcelPPT.Skills.ProjectScopeSkill.get_state()
      :activity_calculator -> NeoExcelPPT.Skills.ActivityCalculatorSkill.get_state()
      :component_calculator -> NeoExcelPPT.Skills.ComponentCalculatorSkill.get_state()
      :effort_aggregator -> NeoExcelPPT.Skills.EffortAggregatorSkill.get_state()
      :buffer_calculator -> NeoExcelPPT.Skills.BufferCalculatorSkill.get_state()
    end
  rescue
    _ -> default_state_for(skill_id)
  end

  defp default_state_for(:project_scope) do
    %{
      total_files: 55220,
      project_type: "ODI → IDMC",
      simple_files: 55000,
      medium_files: 110,
      complex_files: 110,
      component_breakdown: %{simple: 825_000, medium: 16_500, complex: 33_000, total: 874_500}
    }
  end

  defp default_state_for(:activity_calculator) do
    NeoExcelPPT.Skills.ActivityCalculatorSkill.initial_state()
  end

  defp default_state_for(:component_calculator) do
    NeoExcelPPT.Skills.ComponentCalculatorSkill.initial_state()
  end

  defp default_state_for(:effort_aggregator) do
    NeoExcelPPT.Skills.EffortAggregatorSkill.initial_state()
  end

  defp default_state_for(:buffer_calculator) do
    NeoExcelPPT.Skills.BufferCalculatorSkill.initial_state()
  end

  defp get_assignment(activities, activity_id, member) do
    Enum.find_value(activities, false, fn {_key, activity} ->
      cond do
        activity.id == activity_id -> activity.assignments[member]
        child = Enum.find(activity.children, & &1.id == activity_id) -> child.assignments[member]
        true -> nil
      end
    end)
  end

  defp format_number(n) when is_integer(n), do: Number.Delimit.number_to_delimited(n, precision: 0)
  defp format_number(n) when is_float(n), do: Number.Delimit.number_to_delimited(n, precision: 1)
  defp format_number(n), do: to_string(n)

  defp parse_number(str) do
    case Float.parse(str) do
      {n, _} -> n
      :error -> 0
    end
  end

  defp type_color(:simple), do: "text-blue-600"
  defp type_color(:medium), do: "text-yellow-600"
  defp type_color(:complex), do: "text-orange-600"
  defp type_color(_), do: "text-gray-600"
end
