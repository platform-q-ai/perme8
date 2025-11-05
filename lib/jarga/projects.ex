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
  alias Jarga.Workspaces
  alias Jarga.Workspaces.Policies.PermissionsPolicy

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

  Returns {:ok, project} or {:error, :project_not_found}

  ## Examples

      iex> get_project(user, workspace_id, project_id)
      {:ok, %Project{}}

      iex> get_project(user, workspace_id, "non-existent-id")
      {:error, :project_not_found}

  """
  def get_project(%User{} = user, workspace_id, project_id) do
    project =
      Queries.for_user_by_id(user, workspace_id, project_id)
      |> Repo.one()

    case project do
      nil -> {:error, :project_not_found}
      project -> {:ok, project}
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
  Gets a single project by slug for a user in a workspace.

  Returns {:ok, project} or {:error, :project_not_found}

  ## Examples

      iex> get_project_by_slug(user, workspace_id, "my-project")
      {:ok, %Project{}}

      iex> get_project_by_slug(user, workspace_id, "non-existent-slug")
      {:error, :project_not_found}

  """
  def get_project_by_slug(%User{} = user, workspace_id, slug) do
    project =
      Queries.for_user_by_slug(user, workspace_id, slug)
      |> Repo.one()

    case project do
      nil -> {:error, :project_not_found}
      project -> {:ok, project}
    end
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

  The user must have permission to edit the project based on their role and ownership.
  - Members can only edit their own projects
  - Admins and owners can edit any project in the workspace

  ## Examples

      iex> update_project(user, workspace_id, project_id, %{name: "Updated"})
      {:ok, %Project{}}

      iex> update_project(user, workspace_id, project_id, %{name: ""})
      {:error, %Ecto.Changeset{}}

      iex> update_project(user, non_member_workspace_id, project_id, %{name: "Updated"})
      {:error, :unauthorized}

      iex> update_project(member, workspace_id, other_users_project_id, %{name: "Updated"})
      {:error, :forbidden}

  """
  def update_project(%User{} = user, workspace_id, project_id, attrs) do
    with {:ok, member} <- Workspaces.get_member(user, workspace_id),
         {:ok, project} <- Authorization.verify_project_access(user, workspace_id, project_id),
         :ok <- authorize_edit_project(member.role, project, user.id) do
      # Convert atom keys to string keys to avoid mixed keys
      string_attrs =
        attrs
        |> Enum.map(fn {k, v} -> {to_string(k), v} end)
        |> Enum.into(%{})

      result =
        project
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
    end
  end

  defp authorize_edit_project(role, project, user_id) do
    owns_project = project.user_id == user_id

    if PermissionsPolicy.can?(role, :edit_project, owns_resource: owns_project) do
      :ok
    else
      {:error, :forbidden}
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
