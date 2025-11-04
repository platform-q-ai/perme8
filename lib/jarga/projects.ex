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
  alias Jarga.Projects.UseCases.{CreateProject, DeleteProject}

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
  def create_project(%User{} = user, workspace_id, attrs, opts \\ []) do
    CreateProject.execute(
      %{
        actor: user,
        workspace_id: workspace_id,
        attrs: attrs
      },
      opts
    )
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
  Gets a single project by slug for a user in a workspace.

  Raises `Ecto.NoResultsError` if the Project does not exist with that slug,
  if the user is not a member of the workspace, or if the project
  doesn't belong to the specified workspace.

  ## Examples

      iex> get_project_by_slug!(user, workspace_id, "my-project")
      %Project{}

      iex> get_project_by_slug!(user, workspace_id, "non-existent-slug")
      ** (Ecto.NoResultsError)

  """
  def get_project_by_slug!(%User{} = user, workspace_id, slug) do
    Queries.for_user_by_slug(user, workspace_id, slug)
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

        result = project
        |> Project.changeset(string_attrs)
        |> Repo.update()

        # Broadcast project updates to workspace members
        case result do
          {:ok, updated_project} ->
            broadcast_project_update(updated_project)
            {:ok, updated_project}

          error ->
            error
        end

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
  def delete_project(%User{} = user, workspace_id, project_id, opts \\ []) do
    DeleteProject.execute(
      %{
        actor: user,
        workspace_id: workspace_id,
        project_id: project_id
      },
      opts
    )
  end

  # Private functions

  defp broadcast_project_update(project) do
    Phoenix.PubSub.broadcast(
      Jarga.PubSub,
      "workspace:#{project.workspace_id}",
      {:project_updated, project.id, project.name}
    )
  end
end
