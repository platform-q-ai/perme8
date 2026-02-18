defmodule Jarga.Documents.Application.UseCases.UpdateDocument do
  @moduledoc """
  Use case for updating a document.

  ## Business Rules

  - Actor must be a member of the workspace
  - Actor must have permission to edit the document (owner or admin, or document creator)
  - If updating is_pinned, actor must have pin permissions
  - Sends notifications when visibility, pin status, or title changes

  ## Responsibilities

  - Validate actor has workspace membership
  - Authorize update based on role and ownership
  - Update document attributes
  - Send appropriate notifications
  """

  @behaviour Jarga.Documents.Application.UseCases.UseCase

  alias Jarga.Documents.Application.Policies.DocumentAuthorizationPolicy
  alias Jarga.Documents.Domain.Policies.DocumentAccessPolicy
  alias Jarga.Workspaces

  # Default Infrastructure implementations (injected via opts for testing)
  @default_document_schema Jarga.Documents.Infrastructure.Schemas.DocumentSchema
  @default_document_repository Jarga.Documents.Infrastructure.Repositories.DocumentRepository
  @default_notifier Jarga.Documents.Infrastructure.Notifiers.PubSubNotifier
  @default_event_bus Perme8.Events.EventBus

  @doc """
  Executes the update document use case.

  ## Parameters

  - `params` - Map containing:
    - `:actor` - User updating the document
    - `:document_id` - ID of the document to update
    - `:attrs` - Document attributes to update

  - `opts` - Keyword list of options:
    - `:notifier` - Notification service (default: PubSubNotifier)

  ## Returns

  - `{:ok, document}` - Document updated successfully
  - `{:error, reason}` - Operation failed
  """
  @impl true
  def execute(params, opts \\ []) do
    %{
      actor: actor,
      document_id: document_id,
      attrs: attrs
    } = params

    # Extract dependencies from opts
    document_schema = Keyword.get(opts, :document_schema, @default_document_schema)
    document_repository = Keyword.get(opts, :document_repository, @default_document_repository)
    notifier = Keyword.get(opts, :notifier, @default_notifier)
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)

    deps = %{
      document_schema: document_schema,
      document_repository: document_repository,
      notifier: notifier,
      event_bus: event_bus
    }

    with {:ok, document} <-
           get_document_with_workspace_member(actor, document_id, document_repository),
         {:ok, member} <- Workspaces.get_member(actor, document.workspace_id),
         :ok <- authorize_document_update(member.role, document, actor.id, attrs) do
      update_document_and_notify(document, attrs, deps)
    end
  end

  # Get document and verify workspace membership
  defp get_document_with_workspace_member(user, document_id, document_repository) do
    document = document_repository.get_by_id(document_id)

    with {:document, %{} = document} <- {:document, document},
         {:ok, _workspace} <- Workspaces.verify_membership(user, document.workspace_id),
         :ok <- authorize_document_access(user, document) do
      {:ok, document}
    else
      {:document, nil} -> {:error, :document_not_found}
      {:error, :forbidden} -> {:error, :forbidden}
      {:error, _reason} -> {:error, :unauthorized}
    end
  end

  # Check if user can access this document (read permission)
  defp authorize_document_access(user, document) do
    if DocumentAccessPolicy.can_access?(document, user.id) do
      :ok
    else
      {:error, :forbidden}
    end
  end

  # Authorize document update based on role and ownership
  defp authorize_document_update(role, document, user_id, attrs) do
    # If updating is_pinned, check pin permissions
    action_allowed =
      if Map.has_key?(attrs, :is_pinned) do
        DocumentAuthorizationPolicy.can_pin?(document, role, user_id)
      else
        # Otherwise check edit permissions
        DocumentAuthorizationPolicy.can_edit?(document, role, user_id)
      end

    if action_allowed do
      :ok
    else
      {:error, :forbidden}
    end
  end

  # Update document and send notifications
  # Note: We use repository's transaction method to ensure notifications are sent AFTER
  # the database transaction commits successfully
  defp update_document_and_notify(document, attrs, deps) do
    %{
      document_schema: document_schema,
      document_repository: document_repository,
      notifier: notifier,
      event_bus: event_bus
    } = deps

    changeset = document_schema.changeset(document, attrs)
    result = document_repository.update_in_transaction(changeset)

    case result do
      {:ok, updated_document} ->
        # Send notifications AFTER transaction commits
        send_notifications(document, updated_document, attrs, notifier)
        emit_document_change_events(document, updated_document, attrs, event_bus)
        {:ok, updated_document}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  # Send notifications for relevant changes
  defp send_notifications(old_document, updated_document, attrs, notifier) do
    if Map.has_key?(attrs, :is_public) and attrs.is_public != old_document.is_public do
      notifier.notify_document_visibility_changed(updated_document)
    end

    if Map.has_key?(attrs, :is_pinned) and attrs.is_pinned != old_document.is_pinned do
      notifier.notify_document_pinned_changed(updated_document)
    end

    if Map.has_key?(attrs, :title) and attrs.title != old_document.title do
      notifier.notify_document_title_changed(updated_document)
    end
  end

  # Emit domain events for relevant changes
  defp emit_document_change_events(old_document, updated_document, attrs, event_bus) do
    alias Jarga.Documents.Domain.Events.{
      DocumentTitleChanged,
      DocumentVisibilityChanged,
      DocumentPinnedChanged
    }

    base_attrs = %{
      aggregate_id: updated_document.id,
      actor_id: updated_document.user_id,
      document_id: updated_document.id,
      workspace_id: updated_document.workspace_id,
      user_id: updated_document.user_id
    }

    if Map.has_key?(attrs, :is_public) and attrs.is_public != old_document.is_public do
      event =
        DocumentVisibilityChanged.new(Map.put(base_attrs, :is_public, updated_document.is_public))

      event_bus.emit(event)
    end

    if Map.has_key?(attrs, :is_pinned) and attrs.is_pinned != old_document.is_pinned do
      event =
        DocumentPinnedChanged.new(Map.put(base_attrs, :is_pinned, updated_document.is_pinned))

      event_bus.emit(event)
    end

    if Map.has_key?(attrs, :title) and attrs.title != old_document.title do
      event =
        DocumentTitleChanged.new(
          base_attrs
          |> Map.put(:title, updated_document.title)
          |> Map.put(:previous_title, old_document.title)
        )

      event_bus.emit(event)
    end
  end
end
