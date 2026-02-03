defmodule NeoExcelPPT.Skills.Channel do
  @moduledoc """
  Channel module for inter-skill communication.

  Wraps Phoenix.PubSub to provide a simple interface for skills
  to publish and subscribe to named channels.

  Channels are the communication backbone between skills:
  - Skills subscribe to input channels
  - Skills publish to output channels
  - Changes propagate automatically through the skill graph

  ## Example

      # Subscribe to a channel
      Channel.subscribe(:total_files)

      # Publish to a channel
      Channel.publish(:total_files, 55000)

      # The subscriber receives:
      # {:channel_update, :total_files, 55000}
  """

  @pubsub NeoExcelPPT.PubSub

  @doc """
  Subscribe the calling process to a channel.
  The process will receive `{:channel_update, channel, value}` messages.
  """
  def subscribe(channel) when is_atom(channel) do
    Phoenix.PubSub.subscribe(@pubsub, topic(channel))
  end

  @doc """
  Unsubscribe the calling process from a channel.
  """
  def unsubscribe(channel) when is_atom(channel) do
    Phoenix.PubSub.unsubscribe(@pubsub, topic(channel))
  end

  @doc """
  Publish a value to a channel.
  All subscribers will receive `{:channel_update, channel, value}`.
  """
  def publish(channel, value) when is_atom(channel) do
    Phoenix.PubSub.broadcast(@pubsub, topic(channel), {:channel_update, channel, value})
  end

  @doc """
  Publish a value to a channel, excluding the sender.
  """
  def publish_from(channel, value) when is_atom(channel) do
    Phoenix.PubSub.broadcast_from(@pubsub, self(), topic(channel), {:channel_update, channel, value})
  end

  @doc """
  Get all subscribers for a channel.
  Useful for debugging and introspection.
  """
  def subscribers(channel) when is_atom(channel) do
    # Note: This requires Registry tracking, simplified here
    []
  end

  defp topic(channel), do: "skill_channel:#{channel}"
end
