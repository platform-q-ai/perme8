defmodule Jarga.Documents.Infrastructure.Repositories.AuthorizationRepository do
  @moduledoc """
  Infrastructure repository for document authorization queries.

  This module belongs to the Infrastructure layer and handles database operations
  for verifying document access. It encapsulates Ecto queries and Repo calls.

  For pure authorization business rules, see the domain policy modules.
  """

  @behaviour Jarga.Documents.Application.Behaviours.AuthorizationRepositoryBehaviour

  alias Identity.Repo, as: Repo
  alias Identity.Domain.Entities.User
  alias Jarga.Workspaces
  alias Jarga.Documents.Infrastructure.Schemas.DocumentSchema
  alias Jarga.Documents.Infrastructure.Queries.DocumentQueries

  @doc """
  Verifies that a user can create a document in a workspace.
  Returns {:ok, workspace} if authorized, {:error, reason} otherwise.
  """
  def verify_workspace_access(%User{} = user, workspace_id) do
    Workspaces.get_workspace(user, workspace_id)
  end

  @doc """
  Verifies that a user can access a document (owner only).
  Returns {:ok, document} if authorized, {:error, reason} otherwise.
  Returns a domain entity on success.
  """
  def verify_document_access(%User{} = user, document_id) do
    alias Jarga.Documents.Domain.Entities.Document

    case DocumentQueries.base()
         |> DocumentQueries.by_id(document_id)
         |> DocumentQueries.for_user(user)
         |> Repo.one() do
      nil ->
        # Check if document exists at all
        if Repo.get(DocumentSchema, document_id) do
          {:error, :unauthorized}
        else
          {:error, :document_not_found}
        end

      schema ->
        {:ok, Document.from_schema(schema)}
    end
  end

  @doc """
  Verifies that a project belongs to a workspace.
  Returns :ok if valid, {:error, reason} otherwise.

  Delegates to Projects context to maintain proper boundary separation.
  """
  @impl true
  def verify_project_in_workspace(workspace_id, project_id) do
    Jarga.Projects.verify_project_in_workspace(workspace_id, project_id)
  end
end
