defmodule NeoExcelPPT.Skills.Channel do
  @moduledoc """
  Channel - The Global Event Bus.

  Wraps Phoenix.PubSub to provide:
  - Skill-to-skill communication
  - LiveView subscriptions for real-time updates
  - All messages are also routed to HistoryTracker
  """

  @pubsub NeoExcelPPT.PubSub

  @doc "Subscribe to a channel"
  def subscribe(channel) when is_atom(channel) do
    Phoenix.PubSub.subscribe(@pubsub, to_string(channel))
  end

  @doc "Unsubscribe from a channel"
  def unsubscribe(channel) when is_atom(channel) do
    Phoenix.PubSub.unsubscribe(@pubsub, to_string(channel))
  end

  @doc "Broadcast a message to a channel"
  def broadcast(channel, message) when is_atom(channel) do
    Phoenix.PubSub.broadcast(@pubsub, to_string(channel), {:channel_message, channel, message})
  end

  @doc "Broadcast from a specific skill"
  def broadcast_from(skill_id, channel, data) do
    message = %{
      from: skill_id,
      channel: channel,
      data: data,
      timestamp: DateTime.utc_now()
    }
    broadcast(channel, message)
  end

  @doc "Subscribe to all channels in a list"
  def subscribe_all(channels) when is_list(channels) do
    Enum.each(channels, &subscribe/1)
  end

  @doc "Subscribe to the global notification channel (receives all events)"
  def subscribe_global do
    subscribe(:_global_events)
  end

  @doc "Broadcast to global notification channel"
  def broadcast_global(event) do
    broadcast(:_global_events, event)
  end
end
