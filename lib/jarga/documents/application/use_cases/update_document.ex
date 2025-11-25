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

  alias Jarga.Documents.Infrastructure.Schemas.DocumentSchema
  alias Jarga.Documents.Infrastructure.Repositories.DocumentRepository
  alias Jarga.Documents.Infrastructure.Notifiers.PubSubNotifier
  alias Jarga.Documents.Application.Policies.DocumentAuthorizationPolicy
  alias Jarga.Documents.Domain.Policies.DocumentAccessPolicy
  alias Jarga.Workspaces

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

    notifier = Keyword.get(opts, :notifier, PubSubNotifier)

    with {:ok, document} <- get_document_with_workspace_member(actor, document_id),
         {:ok, member} <- Workspaces.get_member(actor, document.workspace_id),
         :ok <- authorize_document_update(member.role, document, actor.id, attrs) do
      update_document_and_notify(document, attrs, notifier)
    end
  end

  # Get document and verify workspace membership
  defp get_document_with_workspace_member(user, document_id) do
    document = DocumentRepository.get_by_id(document_id)

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
  defp update_document_and_notify(document, attrs, notifier) do
    changeset = DocumentSchema.changeset(document, attrs)
    result = DocumentRepository.update_in_transaction(changeset)

    case result do
      {:ok, updated_document} ->
        # Send notifications AFTER transaction commits
        send_notifications(document, updated_document, attrs, notifier)
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
end
