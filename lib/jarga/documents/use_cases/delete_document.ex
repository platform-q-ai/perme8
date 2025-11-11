defmodule Jarga.Documents.UseCases.DeleteDocument do
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

  @behaviour Jarga.Documents.UseCases.UseCase

  alias Jarga.Repo
  alias Jarga.Workspaces
  alias Jarga.Workspaces.Policies.PermissionsPolicy

  @doc """
  Executes the delete document use case.

  ## Parameters

  - `params` - Map containing:
    - `:actor` - User deleting the document
    - `:document_id` - ID of the document to delete

  - `opts` - Keyword list of options (currently unused)

  ## Returns

  - `{:ok, document}` - Document deleted successfully
  - `{:error, reason}` - Operation failed
  """
  @impl true
  def execute(params, _opts \\ []) do
    %{
      actor: actor,
      document_id: document_id
    } = params

    with {:ok, document} <- get_document_with_workspace_member(actor, document_id),
         {:ok, member} <- Workspaces.get_member(actor, document.workspace_id),
         :ok <- authorize_delete_document(member.role, document, actor.id) do
      Repo.delete(document)
    end
  end

  # Get document and verify workspace membership
  defp get_document_with_workspace_member(user, document_id) do
    alias Jarga.Documents.Infrastructure.DocumentRepository

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

  # Check if user can access this document
  defp authorize_document_access(user, document) do
    cond do
      document.user_id == user.id ->
        :ok

      document.is_public ->
        :ok

      true ->
        {:error, :forbidden}
    end
  end

  # Authorize document deletion based on role and ownership
  defp authorize_delete_document(role, document, user_id) do
    owns_document = document.user_id == user_id

    # For delete, we need to check if it's public when not the owner
    if owns_document do
      if PermissionsPolicy.can?(role, :delete_document, owns_resource: true) do
        :ok
      else
        {:error, :forbidden}
      end
    else
      if PermissionsPolicy.can?(role, :delete_document,
           owns_resource: false,
           is_public: document.is_public
         ) do
        :ok
      else
        {:error, :forbidden}
      end
    end
  end
end
