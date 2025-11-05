defmodule Jarga.Pages.Infrastructure.AuthorizationRepository do
  @moduledoc """
  Infrastructure repository for page authorization queries.

  This module belongs to the Infrastructure layer and handles database operations
  for verifying page access. It encapsulates Ecto queries and Repo calls.

  For pure authorization business rules, see the domain policy modules.
  """

  alias Jarga.Repo
  alias Jarga.Accounts.User
  alias Jarga.Workspaces
  alias Jarga.Pages.{Page, Queries}
  import Ecto.Query

  @doc """
  Verifies that a user can create a page in a workspace.
  Returns {:ok, workspace} if authorized, {:error, reason} otherwise.
  """
  def verify_workspace_access(%User{} = user, workspace_id) do
    Workspaces.get_workspace(user, workspace_id)
  end

  @doc """
  Verifies that a user can access a page (owner only).
  Returns {:ok, page} if authorized, {:error, reason} otherwise.
  """
  def verify_page_access(%User{} = user, page_id) do
    case Queries.base()
         |> Queries.by_id(page_id)
         |> Queries.for_user(user)
         |> Repo.one() do
      nil ->
        # Check if page exists at all
        if Repo.get(Page, page_id) do
          {:error, :unauthorized}
        else
          {:error, :page_not_found}
        end

      page ->
        {:ok, page}
    end
  end

  @doc """
  Verifies that a project belongs to a workspace.
  Returns :ok if valid, {:error, reason} otherwise.
  """
  def verify_project_in_workspace(_workspace_id, nil), do: :ok

  def verify_project_in_workspace(workspace_id, project_id) do
    # Check if project exists and belongs to workspace
    query =
      from(p in Jarga.Projects.Project,
        where: p.id == ^project_id and p.workspace_id == ^workspace_id
      )

    case Repo.one(query) do
      nil -> {:error, :project_not_in_workspace}
      _project -> :ok
    end
  end
end
