defmodule Perme8.Events do
  @moduledoc """
  Shared event infrastructure for cross-context communication.

  Provides typed domain events, a PubSub-backed event bus, and
  standardized event handlers for decoupled inter-context reactions.
  """

  use Boundary,
    top_level?: true,
    deps: [],
    exports: [DomainEvent, EventBus, EventHandler, TestEventBus]

  @pubsub Jarga.PubSub

  @doc "Subscribe the calling process to an event topic."
  def subscribe(topic) do
    Phoenix.PubSub.subscribe(@pubsub, topic)
  end

  @doc "Unsubscribe the calling process from an event topic."
  def unsubscribe(topic) do
    Phoenix.PubSub.unsubscribe(@pubsub, topic)
  end
end
