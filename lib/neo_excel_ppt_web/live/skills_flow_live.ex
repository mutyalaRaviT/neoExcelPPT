defmodule NeoExcelPPTWeb.SkillsFlowLive do
  @moduledoc """
  LiveView for visual skill composition using SvelteFlow.
  Provides two-way editing: Visual flow <-> S-Expression DSL
  """
  use NeoExcelPPTWeb, :live_view

  alias NeoExcelPPT.Skills.{DSL, SkillManager}

  @impl true
  def mount(_params, _session, socket) do
    # Get current skills from SkillManager
    skills = get_skills_for_flow()
    wiring = get_wiring_for_flow()
    dsl = DSL.generate_sample_dsl()

    {:ok, assign(socket,
      page_title: "Skills Flow",
      skills: skills,
      wiring: wiring,
      dsl: dsl,
      selected_skill: nil,
      show_dsl_help: false,
      sync_mode: :visual,  # :visual or :dsl - which one is source of truth
      parse_error: nil
    )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="skills-flow-page" class="min-h-screen bg-gray-50">
      <!-- Header -->
      <div class="bg-white border-b border-gray-200 px-6 py-4">
        <div class="flex justify-between items-center">
          <div>
            <h1 class="text-2xl font-bold text-gray-900">Skills Flow Editor</h1>
            <p class="text-sm text-gray-500 mt-1">
              Visual composition of skills with S-expression DSL
            </p>
          </div>
          <div class="flex items-center gap-4">
            <!-- Sync Mode Toggle -->
            <div class="flex items-center gap-2 bg-gray-100 rounded-lg p-1">
              <button
                phx-click="set_sync_mode"
                phx-value-mode="visual"
                class={"px-3 py-1.5 text-sm font-medium rounded-md transition-colors " <>
                  if(@sync_mode == :visual, do: "bg-white shadow text-blue-600", else: "text-gray-600 hover:text-gray-900")}
              >
                Visual → DSL
              </button>
              <button
                phx-click="set_sync_mode"
                phx-value-mode="dsl"
                class={"px-3 py-1.5 text-sm font-medium rounded-md transition-colors " <>
                  if(@sync_mode == :dsl, do: "bg-white shadow text-blue-600", else: "text-gray-600 hover:text-gray-900")}
              >
                DSL → Visual
              </button>
            </div>
            <!-- Action Buttons -->
            <button
              phx-click="apply_dsl"
              class="px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-lg hover:bg-blue-700 transition-colors"
            >
              Apply Changes
            </button>
            <button
              phx-click="reset_to_defaults"
              class="px-4 py-2 bg-gray-200 text-gray-700 text-sm font-medium rounded-lg hover:bg-gray-300 transition-colors"
            >
              Reset
            </button>
          </div>
        </div>
      </div>

      <!-- Main Content: Split View -->
      <div class="flex h-[calc(100vh-120px)]">
        <!-- Left: Visual Flow Editor (SvelteFlow) -->
        <div class="flex-1 p-4">
          <div class="h-full bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
            <div class="bg-gray-50 border-b border-gray-200 px-4 py-2 flex justify-between items-center">
              <h2 class="text-sm font-semibold text-gray-700">Visual Editor</h2>
              <div class="flex items-center gap-2 text-xs text-gray-500">
                <span class="flex items-center gap-1">
                  <span class="w-2 h-2 bg-green-500 rounded-full"></span>
                  Inputs
                </span>
                <span class="flex items-center gap-1">
                  <span class="w-2 h-2 bg-blue-500 rounded-full"></span>
                  Outputs
                </span>
              </div>
            </div>
            <!-- SvelteFlow Component via LiveSvelte -->
            <%= live_svelte(
              @socket,
              "SkillFlow",
              %{
                skills: @skills,
                wiring: @wiring
              },
              id: "skill-flow-editor"
            ) %>
          </div>
        </div>

        <!-- Right: DSL Editor -->
        <div class="w-[500px] p-4 pl-0">
          <div class="h-full bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden flex flex-col">
            <%= live_svelte(
              @socket,
              "DSLEditor",
              %{
                dsl: @dsl,
                readonly: @sync_mode == :visual
              },
              id: "dsl-editor"
            ) %>
          </div>
        </div>
      </div>

      <!-- Selected Skill Panel (Slide-out) -->
      <%= if @selected_skill do %>
        <div class="fixed inset-y-0 right-0 w-96 bg-white shadow-xl border-l border-gray-200 z-50 transform transition-transform">
          <div class="p-6">
            <div class="flex justify-between items-center mb-6">
              <h3 class="text-lg font-semibold text-gray-900">
                <%= @selected_skill.name %>
              </h3>
              <button phx-click="close_skill_panel" class="text-gray-400 hover:text-gray-600">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            <!-- Skill Details -->
            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-500 mb-1">ID</label>
                <code class="text-sm bg-gray-100 px-2 py-1 rounded"><%= @selected_skill.id %></code>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-500 mb-1">Input Channels</label>
                <div class="flex flex-wrap gap-2">
                  <%= for input <- @selected_skill.inputs || [] do %>
                    <span class="px-2 py-1 bg-green-100 text-green-700 text-xs rounded-full">
                      <%= input %>
                    </span>
                  <% end %>
                </div>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-500 mb-1">Output Channels</label>
                <div class="flex flex-wrap gap-2">
                  <%= for output <- @selected_skill.outputs || [] do %>
                    <span class="px-2 py-1 bg-blue-100 text-blue-700 text-xs rounded-full">
                      <%= output %>
                    </span>
                  <% end %>
                </div>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-500 mb-1">Current State</label>
                <pre class="text-xs bg-gray-50 p-3 rounded-lg overflow-auto max-h-48"><%= Jason.encode!(@selected_skill.state || %{}, pretty: true) %></pre>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- DSL Help Modal -->
      <%= if @show_dsl_help do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" phx-click="hide_dsl_help">
          <div class="bg-white rounded-xl shadow-2xl max-w-2xl w-full max-h-[80vh] overflow-hidden" phx-click-away="hide_dsl_help">
            <div class="bg-gray-50 px-6 py-4 border-b border-gray-200 flex justify-between items-center">
              <h3 class="text-lg font-semibold text-gray-900">S-Expression DSL Reference</h3>
              <button phx-click="hide_dsl_help" class="text-gray-400 hover:text-gray-600">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            <div class="p-6 overflow-auto max-h-[calc(80vh-80px)]">
              <div class="prose prose-sm">
                <h4>Define a Skill</h4>
                <pre class="bg-gray-900 text-gray-100 p-4 rounded-lg text-xs"><code>(define-skill :skill-id
  (inputs :channel1 :channel2)
  (outputs :output1 :output2)
  (state {:key value})
  (compute
    (expression)))</code></pre>

                <h4>Expressions</h4>
                <ul class="text-sm">
                  <li><code>(get state :key)</code> - Get value from state</li>
                  <li><code>(get input :channel)</code> - Get value from input</li>
                  <li><code>(set :key value)</code> - Set state key</li>
                  <li><code>(emit :channel value)</code> - Emit to output channel</li>
                  <li><code>(+ a b)</code>, <code>(- a b)</code>, <code>(* a b)</code>, <code>(/ a b)</code> - Arithmetic</li>
                  <li><code>(let [bindings] body)</code> - Local bindings</li>
                  <li><code>(if cond then else)</code> - Conditional</li>
                </ul>

                <h4>Define Wiring</h4>
                <pre class="bg-gray-900 text-gray-100 p-4 rounded-lg text-xs"><code>(define-wiring
  (connect :skill1:output -> :skill2:input)
  (connect :skill2:output -> :skill3:input))</code></pre>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Parse Error Toast -->
      <%= if @parse_error do %>
        <div class="fixed bottom-4 right-4 bg-red-50 border border-red-200 text-red-800 px-4 py-3 rounded-lg shadow-lg max-w-md">
          <div class="flex items-start gap-3">
            <svg class="w-5 h-5 text-red-500 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <div>
              <p class="font-medium">DSL Parse Error</p>
              <p class="text-sm mt-1"><%= @parse_error %></p>
            </div>
            <button phx-click="clear_error" class="text-red-400 hover:text-red-600">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # Event Handlers
  # ============================================================================

  @impl true
  def handle_event("set_sync_mode", %{"mode" => mode}, socket) do
    mode = String.to_atom(mode)
    {:noreply, assign(socket, sync_mode: mode)}
  end

  @impl true
  def handle_event("apply_dsl", _params, socket) do
    case DSL.parse(socket.assigns.dsl) do
      {:ok, _ast} ->
        # TODO: Apply parsed DSL to create/update skills
        {:noreply, assign(socket, parse_error: nil)}
      {:error, reason} ->
        {:noreply, assign(socket, parse_error: reason)}
    end
  end

  @impl true
  def handle_event("reset_to_defaults", _params, socket) do
    skills = get_skills_for_flow()
    wiring = get_wiring_for_flow()
    dsl = DSL.generate_sample_dsl()

    {:noreply, assign(socket,
      skills: skills,
      wiring: wiring,
      dsl: dsl,
      parse_error: nil
    )}
  end

  @impl true
  def handle_event("skill_selected", %{"skill_id" => skill_id}, socket) do
    skill = Enum.find(socket.assigns.skills, &(&1.id == skill_id))
    {:noreply, assign(socket, selected_skill: skill)}
  end

  @impl true
  def handle_event("close_skill_panel", _params, socket) do
    {:noreply, assign(socket, selected_skill: nil)}
  end

  @impl true
  def handle_event("skill_position_changed", %{"skill_id" => skill_id, "position" => position}, socket) do
    skills = Enum.map(socket.assigns.skills, fn skill ->
      if skill.id == skill_id do
        %{skill | position: position}
      else
        skill
      end
    end)
    {:noreply, assign(socket, skills: skills)}
  end

  @impl true
  def handle_event("skill_connected", params, socket) do
    %{"source" => source, "source_channel" => src_ch, "target" => target, "target_channel" => tgt_ch} = params

    wiring = Map.update(
      socket.assigns.wiring,
      "#{source}:#{src_ch}",
      ["#{target}:#{tgt_ch}"],
      &[["#{target}:#{tgt_ch}"] | &1]
    )

    # Update DSL to reflect new wiring
    {:noreply, assign(socket, wiring: wiring) |> sync_dsl_from_visual()}
  end

  @impl true
  def handle_event("skill_disconnected", params, socket) do
    %{"source" => source, "source_channel" => src_ch, "target" => target, "target_channel" => tgt_ch} = params

    wiring = Map.update(
      socket.assigns.wiring,
      "#{source}:#{src_ch}",
      [],
      &List.delete(&1, "#{target}:#{tgt_ch}")
    )

    {:noreply, assign(socket, wiring: wiring) |> sync_dsl_from_visual()}
  end

  @impl true
  def handle_event("dsl_changed", %{"dsl" => dsl}, socket) do
    {:noreply, assign(socket, dsl: dsl, parse_error: nil)}
  end

  @impl true
  def handle_event("dsl_apply", %{"dsl" => dsl}, socket) do
    socket = assign(socket, dsl: dsl)

    case DSL.parse(dsl) do
      {:ok, _ast} ->
        # Sync visual from DSL
        {:noreply, socket |> assign(parse_error: nil) |> sync_visual_from_dsl()}
      {:error, reason} ->
        {:noreply, assign(socket, parse_error: reason)}
    end
  end

  @impl true
  def handle_event("show_dsl_help", _params, socket) do
    {:noreply, assign(socket, show_dsl_help: true)}
  end

  @impl true
  def handle_event("hide_dsl_help", _params, socket) do
    {:noreply, assign(socket, show_dsl_help: false)}
  end

  @impl true
  def handle_event("clear_error", _params, socket) do
    {:noreply, assign(socket, parse_error: nil)}
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp get_skills_for_flow do
    # Get skills from SkillManager or use defaults
    [
      %{
        id: "project_scope",
        name: "Project Scope",
        inputs: [:file_counts],
        outputs: [:total_files, :component_breakdown],
        state: %{simple: 0, medium: 0, complex: 0},
        position: %{x: 50, y: 100}
      },
      %{
        id: "component_calculator",
        name: "Component Calculator",
        inputs: [:file_count, :breakdown, :automation_pct],
        outputs: [:scaled_effort, :component_days],
        state: %{base_hours: 15},
        position: %{x: 300, y: 50}
      },
      %{
        id: "activity_calculator",
        name: "Activity Calculator",
        inputs: [:activity_update, :team_assignment],
        outputs: [:activity_totals, :team_effort],
        state: %{activities: %{}},
        position: %{x: 300, y: 200}
      },
      %{
        id: "effort_aggregator",
        name: "Effort Aggregator",
        inputs: [:component_effort, :activity_effort, :buffer_days],
        outputs: [:total_days, :effort_breakdown],
        state: %{},
        position: %{x: 550, y: 100}
      },
      %{
        id: "buffer_calculator",
        name: "Buffer Calculator",
        inputs: [:base_days, :buffer_config],
        outputs: [:buffer_days, :buffer_breakdown],
        state: %{leave_pct: 10, dependency_pct: 15, learning_pct: 20},
        position: %{x: 300, y: 350}
      }
    ]
  end

  defp get_wiring_for_flow do
    %{
      "project_scope:total_files" => ["component_calculator:file_count"],
      "project_scope:component_breakdown" => ["component_calculator:breakdown"],
      "component_calculator:scaled_effort" => ["effort_aggregator:component_effort"],
      "activity_calculator:activity_totals" => ["effort_aggregator:activity_effort"],
      "buffer_calculator:buffer_days" => ["effort_aggregator:buffer_days"]
    }
  end

  defp sync_dsl_from_visual(socket) do
    # Convert current visual state to DSL
    # For now, just regenerate the sample
    dsl = DSL.generate_sample_dsl()
    assign(socket, dsl: dsl)
  end

  defp sync_visual_from_dsl(socket) do
    # Parse DSL and update visual components
    # For now, keep current visual state
    socket
  end

  # Helper for LiveSvelte
  defp live_svelte(socket, component, props, opts) do
    id = Keyword.get(opts, :id, component)

    assigns = %{
      id: id,
      component: component,
      props: Jason.encode!(props)
    }

    ~H"""
    <div
      id={@id}
      phx-hook="LiveSvelte"
      data-component={@component}
      data-props={@props}
      class="h-full"
    >
    </div>
    """
  end
end
