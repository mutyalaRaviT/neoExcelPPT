defmodule NeoExcelPPTWeb.CoreComponents do
  @moduledoc """
  Provides core UI components for NeoExcelPPT.

  Components follow a skills-based architecture where each component
  can be connected to skill actors for real-time updates.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  @doc """
  Renders a flash message group.
  """
  attr :flash, :map, required: true
  attr :id, :string, default: "flash-group"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} class="fixed top-4 right-4 z-50 space-y-2">
      <.flash kind={:info} title="Info" flash={@flash} />
      <.flash kind={:error} title="Error" flash={@flash} />
    </div>
    """
  end

  @doc """
  Renders a flash message.
  """
  attr :id, :string, default: nil
  attr :flash, :map, default: %{}
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], required: true
  attr :rest, :global

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class={[
        "rounded-lg p-4 shadow-lg",
        @kind == :info && "bg-blue-50 text-blue-800 border border-blue-200",
        @kind == :error && "bg-red-50 text-red-800 border border-red-200"
      ]}
      {@rest}
    >
      <div class="flex items-start gap-3">
        <span :if={@kind == :info} class="text-blue-500">
          <svg class="h-5 w-5" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
          </svg>
        </span>
        <span :if={@kind == :error} class="text-red-500">
          <svg class="h-5 w-5" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
          </svg>
        </span>
        <div class="flex-1">
          <p :if={@title} class="font-medium"><%= @title %></p>
          <p class="text-sm"><%= msg %></p>
        </div>
        <button type="button" class="text-gray-400 hover:text-gray-600">
          <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
          </svg>
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a card container.
  """
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <div class={"bg-white rounded-xl shadow-sm border border-gray-200 #{@class}"}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  @doc """
  Renders a card header with title.
  """
  attr :icon, :string, default: nil
  attr :title, :string, required: true
  attr :class, :string, default: ""
  slot :actions

  def card_header(assigns) do
    ~H"""
    <div class={"flex items-center justify-between p-4 border-b border-gray-100 #{@class}"}>
      <div class="flex items-center gap-2">
        <span :if={@icon} class="text-lg"><%= @icon %></span>
        <h2 class="font-semibold text-gray-900"><%= @title %></h2>
      </div>
      <div :if={@actions != []} class="flex items-center gap-2">
        <%= render_slot(@actions) %>
      </div>
    </div>
    """
  end

  @doc """
  Renders a stat display.
  """
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :color, :string, default: "blue"
  attr :size, :string, default: "md"

  def stat(assigns) do
    ~H"""
    <div>
      <p class="text-sm text-gray-500"><%= @label %></p>
      <p class={[
        "font-mono font-bold",
        @size == "lg" && "text-3xl",
        @size == "md" && "text-xl",
        @size == "sm" && "text-base",
        @color == "blue" && "text-blue-600",
        @color == "green" && "text-green-600",
        @color == "orange" && "text-orange-500",
        @color == "gray" && "text-gray-900"
      ]}>
        <%= @value %>
      </p>
    </div>
    """
  end

  @doc """
  Renders a data table.
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_click, :any, default: nil

  slot :col, required: true do
    attr :label, :string
    attr :class, :string
  end

  def table(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th :for={col <- @col} class={"px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider #{col[:class]}"}>
              <%= col[:label] %>
            </th>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          <tr :for={row <- @rows} class="hover:bg-gray-50">
            <td :for={col <- @col} class={"px-4 py-3 text-sm #{col[:class]}"}>
              <%= render_slot(col, row) %>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a checkbox.
  """
  attr :checked, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :name, :string, default: nil
  attr :rest, :global

  def checkbox(assigns) do
    ~H"""
    <div class={[
      "w-5 h-5 rounded border flex items-center justify-center",
      @checked && "bg-blue-500 border-blue-500",
      !@checked && "bg-white border-gray-300",
      @disabled && "opacity-50 cursor-not-allowed"
    ]} {@rest}>
      <svg :if={@checked} class="w-3 h-3 text-white" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
      </svg>
    </div>
    """
  end

  @doc """
  Renders a badge.
  """
  attr :color, :string, default: "gray"
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium",
      @color == "green" && "bg-green-100 text-green-800",
      @color == "blue" && "bg-blue-100 text-blue-800",
      @color == "yellow" && "bg-yellow-100 text-yellow-800",
      @color == "red" && "bg-red-100 text-red-800",
      @color == "gray" && "bg-gray-100 text-gray-800",
      @class
    ]}>
      <%= render_slot(@inner_block) %>
    </span>
    """
  end

  @doc """
  Renders an input field.
  """
  attr :type, :string, default: "text"
  attr :name, :string, required: true
  attr :value, :any, default: nil
  attr :class, :string, default: ""
  attr :rest, :global

  def input(assigns) do
    ~H"""
    <input
      type={@type}
      name={@name}
      value={@value}
      class={[
        "block w-full rounded-md border-gray-300 shadow-sm",
        "focus:border-blue-500 focus:ring-blue-500 sm:text-sm",
        @class
      ]}
      {@rest}
    />
    """
  end

  @doc """
  Renders a button.
  """
  attr :type, :string, default: "button"
  attr :variant, :string, default: "primary"
  attr :size, :string, default: "md"
  attr :class, :string, default: ""
  attr :rest, :global
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "inline-flex items-center justify-center font-medium rounded-lg",
        @variant == "primary" && "bg-blue-600 text-white hover:bg-blue-700",
        @variant == "secondary" && "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50",
        @variant == "ghost" && "text-gray-600 hover:text-gray-900 hover:bg-gray-100",
        @size == "sm" && "px-3 py-1.5 text-sm",
        @size == "md" && "px-4 py-2 text-sm",
        @size == "lg" && "px-6 py-3 text-base",
        @class
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  defp hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end
end
