defmodule Jarga.Projects.Infrastructure.Repositories.AuthorizationRepository do
  @moduledoc """
  Infrastructure repository for project authorization queries.

  This module belongs to the Infrastructure layer and handles database operations
  for verifying project access. It encapsulates Ecto queries and Repo calls.

  For pure authorization business rules, see the domain policy modules.
  """

  @behaviour Jarga.Projects.Application.Behaviours.AuthorizationRepositoryBehaviour

  alias Identity.Domain.Entities.User
  alias Jarga.Projects.Infrastructure.Queries.Queries
  alias Jarga.Workspaces
  alias Identity.Repo, as: Repo

  @doc """
  Verifies that a user has access to a project within a workspace.

  A user has access to a project if:
  - They are a member of the workspace
  - The project exists and belongs to that workspace

  Returns `{:ok, project}` if the user has access, or an error tuple otherwise.

  ## Returns

  - `{:ok, project}` - User has access to the project
  - `{:error, :unauthorized}` - User is not a member of the workspace
  - `{:error, :workspace_not_found}` - Workspace does not exist
  - `{:error, :project_not_found}` - Project does not exist or doesn't belong to workspace

  ## Examples

      iex> verify_project_access(user, workspace_id, project_id)
      {:ok, %Project{}}

      iex> verify_project_access(user, non_member_workspace_id, project_id)
      {:error, :unauthorized}

      iex> verify_project_access(user, workspace_id, invalid_project_id)
      {:error, :project_not_found}

  """
  @impl true
  def verify_project_access(%User{} = user, workspace_id, project_id, repo \\ Repo) do
    case Queries.for_user_by_id(user, workspace_id, project_id) |> repo.one() do
      nil ->
        # Check if user is authorized for the workspace first
        case Workspaces.verify_membership(user, workspace_id) do
          {:ok, _workspace} ->
            # User is authorized but project doesn't exist or doesn't belong to workspace
            {:error, :project_not_found}

          {:error, reason} ->
            {:error, reason}
        end

      project_schema ->
        # Returns schema for use cases that need to perform updates/deletes
        # Repository methods will convert to domain entities
        {:ok, project_schema}
    end
  end
end
