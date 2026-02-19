defmodule Perme8.Events.EventBus do
  @moduledoc """
  Central event dispatcher. Wraps Phoenix.PubSub for structured event broadcasting.

  ## Topics

  Each event is broadcast to multiple topics:

  - `events:{context}` — All events for a context (e.g., `events:projects`)
  - `events:{context}:{aggregate_type}` — Scoped by aggregate (e.g., `events:projects:project`)
  - `events:workspace:{workspace_id}` — Workspace-scoped events (when workspace_id present)
  - `events:user:{target_user_id}` — User-scoped events (when target_user_id present)
  """

  @pubsub Jarga.PubSub

  @doc """
  Emits a domain event to all derived topics.

  Broadcasts the event struct to context, aggregate, workspace, and user topics.

  ## Options

  Reserved for future use (e.g., correlation IDs, tracing metadata).
  Currently unused but accepted for forward-compatible call sites.
  """
  def emit(event, _opts \\ []) do
    topics = derive_topics(event)

    Enum.each(topics, fn topic ->
      Phoenix.PubSub.broadcast(@pubsub, topic, event)
    end)

    :ok
  end

  @doc """
  Emits multiple domain events sequentially.

  See `emit/2` for available options.
  """
  def emit_all(events, opts \\ []) do
    Enum.each(events, &emit(&1, opts))
    :ok
  end

  defp derive_topics(event) do
    event_type = event.event_type
    aggregate_type = event.aggregate_type
    context = event_type |> String.split(".") |> List.first()

    base_topics = [
      "events:#{context}",
      "events:#{context}:#{aggregate_type}"
    ]

    topics =
      if event.workspace_id do
        base_topics ++ ["events:workspace:#{event.workspace_id}"]
      else
        base_topics
      end

    if Map.get(event, :target_user_id) do
      topics ++ ["events:user:#{event.target_user_id}"]
    else
      topics
    end
  end
end
