defmodule NeoExcelPPTWeb.SkillsLive do
  @moduledoc """
  Skills LiveView - View and manage skill actors.

  Shows:
  - All registered skills
  - Skill communication graph
  - Skill states
  - Input/output channels
  """

  use NeoExcelPPTWeb, :live_view

  alias NeoExcelPPT.Skills.{SkillManager, Channel}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Channel.subscribe(:_global_events)
    end

    skills = SkillManager.get_skills()
    graph = SkillManager.get_dependency_graph()

    socket =
      socket
      |> assign(:page_title, "Skills Registry")
      |> assign(:skills, skills)
      |> assign(:graph, graph)
      |> assign(:selected_skill, nil)

    {:ok, socket}
  end

  @impl true
  def handle_info({:channel_message, :_global_events, _event}, socket) do
    # Refresh skills on any event
    skills = SkillManager.get_skills()
    {:noreply, assign(socket, :skills, skills)}
  end

  @impl true
  def handle_event("select_skill", %{"skill" => skill_id}, socket) do
    {:noreply, assign(socket, :selected_skill, String.to_atom(skill_id))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="skills-container" class="min-h-screen bg-gray-50 p-6">
      <div class="max-w-6xl mx-auto space-y-6">

        <!-- Header -->
        <div class="flex justify-between items-center">
          <div>
            <h1 class="text-2xl font-bold text-gray-900">Skills Registry</h1>
            <p class="text-gray-500 mt-1">View and manage skill actors</p>
          </div>
          <div class="flex items-center gap-2">
            <span class="text-sm text-gray-500">
              <%= length(@skills) %> skills registered
            </span>
          </div>
        </div>

        <!-- Skills Grid -->
        <div id="skills-grid" class="grid grid-cols-2 gap-6">
          <%= for skill <- @skills do %>
            <div
              id={"skill-#{skill.id}"}
              class={"bg-white rounded-xl shadow-sm border-2 p-6 cursor-pointer transition-all #{if @selected_skill == skill.id, do: "border-blue-500", else: "border-gray-200 hover:border-gray-300"}"}
              phx-click="select_skill"
              phx-value-skill={skill.id}
            >
              <div class="flex items-start justify-between">
                <div>
                  <h3 class="text-lg font-semibold text-gray-900">
                    <%= skill.id %>
                  </h3>
                  <p class="text-sm text-gray-500 font-mono">
                    <%= skill.module %>
                  </p>
                </div>
                <span id={"skill-#{skill.id}-status"} class={"px-2 py-1 rounded-full text-xs font-medium #{if skill.status == :running, do: "bg-green-100 text-green-800", else: "bg-red-100 text-red-800"}"}>
                  <%= skill.status %>
                </span>
              </div>

              <div class="mt-4 space-y-3">
                <!-- Input Channels -->
                <div>
                  <p class="text-xs text-gray-500 uppercase mb-1">Input Channels</p>
                  <div class="flex flex-wrap gap-1">
                    <%= for channel <- skill.input_channels do %>
                      <span class="px-2 py-0.5 bg-green-100 text-green-700 rounded text-xs">
                        <%= channel %>
                      </span>
                    <% end %>
                  </div>
                </div>

                <!-- Output Channels -->
                <div>
                  <p class="text-xs text-gray-500 uppercase mb-1">Output Channels</p>
                  <div class="flex flex-wrap gap-1">
                    <%= for channel <- skill.output_channels do %>
                      <span class="px-2 py-0.5 bg-blue-100 text-blue-700 rounded text-xs">
                        <%= channel %>
                      </span>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>

        <!-- Wiring Diagram -->
        <div id="skills-wiring" class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <h2 class="text-lg font-semibold text-gray-900 mb-4">Skill Communication Graph</h2>

          <div class="space-y-4">
            <%= for edge <- @graph.edges do %>
              <div class="flex items-center gap-4 text-sm">
                <span class="px-3 py-1 bg-gray-100 rounded font-medium">
                  <%= edge.from %>
                </span>
                <span class="text-gray-400">
                  :<%= edge.from_channel %> →
                </span>
                <span class="px-3 py-1 bg-blue-100 text-blue-700 rounded font-medium">
                  <%= edge.to %>
                </span>
                <span class="text-gray-400">
                  :<%= edge.to_channel %>
                </span>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Architecture Info -->
        <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <h2 class="text-lg font-semibold text-gray-900 mb-4">💡 Skills Architecture</h2>
          <ul class="space-y-2 text-sm text-gray-600">
            <li class="flex items-start gap-2">
              <span class="text-green-500">●</span>
              <span><strong>Skills are Actors:</strong> Each skill is an Elixir GenServer (actor process)</span>
            </li>
            <li class="flex items-start gap-2">
              <span class="text-blue-500">●</span>
              <span><strong>Pure Functions:</strong> Skills wrap pure compute functions with state management</span>
            </li>
            <li class="flex items-start gap-2">
              <span class="text-purple-500">●</span>
              <span><strong>Channel Communication:</strong> Skills communicate via Phoenix PubSub channels</span>
            </li>
            <li class="flex items-start gap-2">
              <span class="text-amber-500">●</span>
              <span><strong>Event Sourcing:</strong> All state changes are recorded for time-travel replay</span>
            </li>
          </ul>
        </div>
      </div>
    </div>
    """
  end
end
