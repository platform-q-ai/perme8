defmodule Perme8.Events.Infrastructure.LegacyBridge do
  @moduledoc """
  Translates structured domain events into legacy PubSub tuple format.

  This bridge ensures backward compatibility during the migration from
  ad-hoc PubSub notifications to structured domain events. It will be
  removed once all consumers have migrated to the new event format.

  ## How It Works

  1. `EventBus.emit/2` calls `broadcast_legacy/1` after broadcasting the structured event
  2. `broadcast_legacy/1` calls `translate/1` to get legacy topic/message pairs
  3. Each pair is broadcast via Phoenix.PubSub on the legacy topic

  Specific translations are added in Phase 2 when event structs are defined.
  """

  @pubsub Jarga.PubSub

  @doc """
  Translates a domain event into a list of `{topic, message}` tuples
  for legacy PubSub broadcasting.

  Returns `[]` for events that have no legacy representation.
  """
  def translate(_event), do: []

  @doc """
  Broadcasts legacy tuple messages for a domain event.

  Calls `translate/1` and broadcasts each resulting `{topic, message}` pair
  on the legacy PubSub.
  """
  def broadcast_legacy(event) do
    event
    |> translate()
    |> Enum.each(fn {topic, message} ->
      Phoenix.PubSub.broadcast(@pubsub, topic, message)
    end)
  end
end
