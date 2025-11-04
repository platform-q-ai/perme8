defmodule Jarga.Projects do
  @moduledoc """
  The Projects context.

  Handles project creation, management within workspaces.
  This module follows Clean Architecture patterns by delegating to:
  - Query Objects (infrastructure layer) for data access
  - Policies (domain layer) for business rules
  """

  # Core context - cannot depend on JargaWeb (interface layer)
  # Exports: Main context module and shared types (Project)
  # Internal modules (Queries, Policies) remain private
  use Boundary,
    top_level?: true,
    deps: [Jarga.Accounts, Jarga.Workspaces, Jarga.Repo],
    exports: [{Project, []}]

  alias Jarga.Repo
  alias Jarga.Accounts.User
  alias Jarga.Projects.{Project, Queries}
  alias Jarga.Projects.Policies.Authorization
  alias Jarga.Workspaces

  @doc """
  Returns the list of projects for a given workspace.

  Only returns non-archived projects if the user is a member of the workspace.

  ## Examples

      iex> list_projects_for_workspace(user, workspace_id)
      [%Project{}, ...]

  """
  def list_projects_for_workspace(%User{} = user, workspace_id) do
    Queries.base()
    |> Queries.for_workspace(workspace_id)
    |> Queries.for_user(user)
    |> Queries.active()
    |> Queries.ordered()
    |> Repo.all()
  end

  @doc """
  Creates a project for a user in a workspace.

  The user must be a member of the workspace to create projects.

  ## Examples

      iex> create_project(user, workspace_id, %{name: "My Project"})
      {:ok, %Project{}}

      iex> create_project(user, workspace_id, %{name: ""})
      {:error, %Ecto.Changeset{}}

      iex> create_project(user, non_member_workspace_id, %{name: "Project"})
      {:error, :unauthorized}

  """
  def create_project(%User{} = user, workspace_id, attrs) do
    # First verify the user is a member of the workspace
    case Workspaces.verify_membership(user, workspace_id) do
      {:ok, _workspace} ->
        # Convert atom keys to string keys to avoid mixed keys
        string_attrs =
          attrs
          |> Enum.map(fn {k, v} -> {to_string(k), v} end)
          |> Enum.into(%{})
          |> Map.put("user_id", user.id)
          |> Map.put("workspace_id", workspace_id)

        %Project{}
        |> Project.changeset(string_attrs)
        |> Repo.insert()

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets a single project for a user in a workspace.

  Raises `Ecto.NoResultsError` if the Project does not exist,
  if the user is not a member of the workspace, or if the project
  doesn't belong to the specified workspace.

  ## Examples

      iex> get_project!(user, workspace_id, project_id)
      %Project{}

      iex> get_project!(user, workspace_id, "non-existent-id")
      ** (Ecto.NoResultsError)

  """
  def get_project!(%User{} = user, workspace_id, project_id) do
    Queries.for_user_by_id(user, workspace_id, project_id)
    |> Repo.one!()
  end

  @doc """
  Updates a project for a user in a workspace.

  The user must be a member of the workspace to update projects.

  ## Examples

      iex> update_project(user, workspace_id, project_id, %{name: "Updated"})
      {:ok, %Project{}}

      iex> update_project(user, workspace_id, project_id, %{name: ""})
      {:error, %Ecto.Changeset{}}

      iex> update_project(user, non_member_workspace_id, project_id, %{name: "Updated"})
      {:error, :unauthorized}

  """
  def update_project(%User{} = user, workspace_id, project_id, attrs) do
    case Authorization.verify_project_access(user, workspace_id, project_id) do
      {:ok, project} ->
        # Convert atom keys to string keys to avoid mixed keys
        string_attrs =
          attrs
          |> Enum.map(fn {k, v} -> {to_string(k), v} end)
          |> Enum.into(%{})

        project
        |> Project.changeset(string_attrs)
        |> Repo.update()

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes a project for a user in a workspace.

  The user must be a member of the workspace to delete projects.

  ## Examples

      iex> delete_project(user, workspace_id, project_id)
      {:ok, %Project{}}

      iex> delete_project(user, non_member_workspace_id, project_id)
      {:error, :unauthorized}

  """
  def delete_project(%User{} = user, workspace_id, project_id) do
    case Authorization.verify_project_access(user, workspace_id, project_id) do
      {:ok, project} ->
        Repo.delete(project)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
