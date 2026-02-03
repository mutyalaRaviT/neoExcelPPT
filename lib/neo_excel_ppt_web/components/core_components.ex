defmodule NeoExcelPPTWeb.CoreComponents do
  @moduledoc """
  Core UI components for NeoExcelPPT.

  These components provide the foundation for all UI elements
  and follow the Skills-Actors architecture.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.JS

  @doc """
  Renders flash messages.
  """
  attr :flash, :map, required: true
  attr :kind, :atom, values: [:info, :error], default: :info

  def flash(assigns) do
    ~H"""
    <div
      :if={msg = Phoenix.Flash.get(@flash, @kind)}
      class={[
        "rounded-lg p-4 mb-4",
        @kind == :info && "bg-blue-50 text-blue-800",
        @kind == :error && "bg-red-50 text-red-800"
      ]}
    >
      <%= msg %>
    </div>
    """
  end

  @doc """
  Renders a flash group.
  """
  attr :flash, :map, required: true

  def flash_group(assigns) do
    ~H"""
    <div class="fixed top-4 right-4 z-50 space-y-2">
      <.flash flash={@flash} kind={:info} />
      <.flash flash={@flash} kind={:error} />
    </div>
    """
  end

  @doc """
  Renders a simple form.
  """
  attr :for, :any, required: true
  attr :as, :atom, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} {@rest}>
      <%= render_slot(@inner_block, f) %>
    </.form>
    """
  end

  @doc """
  Renders a button.
  """
  attr :type, :string, default: "button"
  attr :variant, :string, default: "primary"
  attr :class, :string, default: ""
  attr :rest, :global
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "px-4 py-2 rounded-lg font-medium transition-colors",
        @variant == "primary" && "bg-blue-600 text-white hover:bg-blue-700",
        @variant == "secondary" && "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50",
        @variant == "ghost" && "text-gray-600 hover:text-gray-900 hover:bg-gray-100",
        @variant == "danger" && "bg-red-600 text-white hover:bg-red-700",
        @class
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  @doc """
  Renders an input field.
  """
  attr :id, :string, default: nil
  attr :name, :string, required: true
  attr :type, :string, default: "text"
  attr :value, :any, default: nil
  attr :class, :string, default: ""
  attr :rest, :global

  def input(assigns) do
    ~H"""
    <input
      id={@id}
      name={@name}
      type={@type}
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
      @color == "purple" && "bg-purple-100 text-purple-800",
      @color == "gray" && "bg-gray-100 text-gray-800",
      @class
    ]}>
      <%= render_slot(@inner_block) %>
    </span>
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
  Renders a stat display.
  """
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :color, :string, default: "gray"

  def stat(assigns) do
    ~H"""
    <div>
      <p class="text-sm text-gray-500"><%= @label %></p>
      <p class={[
        "text-2xl font-bold font-mono",
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
end
