defmodule Webhooks.Infrastructure.Subscribers.OutboundWebhookHandler do
  @moduledoc """
  EventHandler that listens for project and document events
  and dispatches outbound webhooks to matching subscriptions.

  Subscribes to `events:projects` and `events:documents` topics
  and delegates to the DispatchWebhook use case.
  """

  use Perme8.Events.EventHandler

  alias Jarga.Projects.Domain.Events.{
    ProjectCreated,
    ProjectUpdated,
    ProjectDeleted,
    ProjectArchived
  }

  alias Jarga.Documents.Domain.Events.{
    DocumentCreated,
    DocumentDeleted,
    DocumentTitleChanged,
    DocumentVisibilityChanged,
    DocumentPinnedChanged
  }

  @default_dispatch_fn &Webhooks.Application.UseCases.DispatchWebhook.execute/2

  @impl Perme8.Events.EventHandler
  def subscriptions do
    ["events:projects", "events:documents"]
  end

  @impl Perme8.Events.EventHandler
  def handle_event(event) do
    handle_event(event, [])
  end

  @doc """
  Handle an event with optional DI for the dispatch function.

  Accepts `dispatch_fn: fn/2` in opts for testing.
  """
  def handle_event(%ProjectCreated{} = event, opts) do
    dispatch(event, "project.created", opts)
  end

  def handle_event(%ProjectUpdated{} = event, opts) do
    dispatch(event, "project.updated", opts)
  end

  def handle_event(%ProjectDeleted{} = event, opts) do
    dispatch(event, "project.deleted", opts)
  end

  def handle_event(%ProjectArchived{} = event, opts) do
    dispatch(event, "project.archived", opts)
  end

  def handle_event(%DocumentCreated{} = event, opts) do
    dispatch(event, "document.created", opts)
  end

  def handle_event(%DocumentDeleted{} = event, opts) do
    dispatch(event, "document.deleted", opts)
  end

  def handle_event(%DocumentTitleChanged{} = event, opts) do
    dispatch(event, "document.title_changed", opts)
  end

  def handle_event(%DocumentVisibilityChanged{} = event, opts) do
    dispatch(event, "document.visibility_changed", opts)
  end

  def handle_event(%DocumentPinnedChanged{} = event, opts) do
    dispatch(event, "document.pinned_changed", opts)
  end

  def handle_event(_event, _opts), do: :ok

  defp dispatch(event, event_type, opts) do
    dispatch_fn = Keyword.get(opts, :dispatch_fn, @default_dispatch_fn)

    params = %{
      workspace_id: event.workspace_id,
      event_type: event_type,
      payload: build_payload(event, event_type)
    }

    case dispatch_fn.(params, opts) do
      {:ok, _deliveries} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_payload(event, event_type) do
    %{
      event_type: event_type,
      aggregate_id: event.aggregate_id,
      workspace_id: event.workspace_id,
      actor_id: event.actor_id,
      occurred_at: event.occurred_at,
      data: event_data(event)
    }
  end

  defp event_data(%ProjectCreated{} = e),
    do: %{project_id: e.project_id, name: e.name, slug: e.slug}

  defp event_data(%ProjectUpdated{} = e),
    do: Map.from_struct(e) |> Map.take([:project_id, :name, :slug])

  defp event_data(%ProjectDeleted{} = e),
    do: Map.from_struct(e) |> Map.take([:project_id])

  defp event_data(%ProjectArchived{} = e),
    do: Map.from_struct(e) |> Map.take([:project_id])

  defp event_data(%DocumentCreated{} = e),
    do: %{document_id: e.document_id, project_id: e.project_id, title: e.title}

  defp event_data(%DocumentDeleted{} = e),
    do: Map.from_struct(e) |> Map.take([:document_id])

  defp event_data(%DocumentTitleChanged{} = e),
    do: Map.from_struct(e) |> Map.take([:document_id, :title])

  defp event_data(%DocumentVisibilityChanged{} = e),
    do: Map.from_struct(e) |> Map.take([:document_id])

  defp event_data(%DocumentPinnedChanged{} = e),
    do: Map.from_struct(e) |> Map.take([:document_id])

  defp event_data(_event), do: %{}
end
