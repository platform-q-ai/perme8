defmodule Jarga.Documents.Application.UseCases.DeleteDocument do
  @moduledoc """
  Use case for deleting a document.

  ## Business Rules

  - Actor must be a member of the workspace
  - Actor must have permission to delete the document:
    - Own documents: Owner can delete if they have delete_document permission
    - Others' documents: Only admin/owner can delete public documents
  - Deletes the document (cascade will handle related records)

  ## Responsibilities

  - Validate actor has workspace membership
  - Authorize deletion based on role and ownership
  - Delete the document
  """

  @behaviour Jarga.Documents.Application.UseCases.UseCase

  alias Jarga.Workspaces
  alias Jarga.Documents.Application.Policies.DocumentAuthorizationPolicy
  alias Jarga.Documents.Domain.Policies.DocumentAccessPolicy

  # Default Infrastructure implementations (injected via opts for testing)
  @default_document_repository Jarga.Documents.Infrastructure.Repositories.DocumentRepository
  @default_event_bus Perme8.Events.EventBus

  @doc """
  Executes the delete document use case.

  ## Parameters

  - `params` - Map containing:
    - `:actor` - User deleting the document
    - `:document_id` - ID of the document to delete

  - `opts` - Keyword list of options

  ## Returns

  - `{:ok, document}` - Document deleted successfully
  - `{:error, reason}` - Operation failed
  """
  @impl true
  def execute(params, opts \\ []) do
    %{
      actor: actor,
      document_id: document_id
    } = params

    # Extract dependencies from opts
    document_repository = Keyword.get(opts, :document_repository, @default_document_repository)
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)

    deps = %{
      document_repository: document_repository,
      event_bus: event_bus
    }

    with {:ok, document} <-
           get_document_with_workspace_member(actor, document_id, document_repository),
         {:ok, member} <- Workspaces.get_member(actor, document.workspace_id),
         :ok <- authorize_delete_document(member.role, document, actor.id) do
      delete_document_and_notify(document, deps)
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

  # Authorize document deletion based on role and ownership
  defp authorize_delete_document(role, document, user_id) do
    if DocumentAuthorizationPolicy.can_delete?(document, role, user_id) do
      :ok
    else
      {:error, :forbidden}
    end
  end

  # Delete document and send notification AFTER transaction commits
  defp delete_document_and_notify(document, deps) do
    %{
      document_repository: document_repository,
      event_bus: event_bus
    } = deps

    result = document_repository.delete_in_transaction(document)

    case result do
      {:ok, deleted_document} ->
        emit_document_deleted_event(deleted_document, document, event_bus)
        {:ok, deleted_document}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  # Emit DocumentDeleted domain event
  defp emit_document_deleted_event(deleted_document, original_document, event_bus) do
    alias Jarga.Documents.Domain.Events.DocumentDeleted

    event =
      DocumentDeleted.new(%{
        aggregate_id: deleted_document.id,
        actor_id: original_document.user_id,
        document_id: deleted_document.id,
        workspace_id: original_document.workspace_id,
        user_id: original_document.user_id
      })

    event_bus.emit(event)
  end
end
