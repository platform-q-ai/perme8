defmodule Jarga.Workspaces do
  @moduledoc """
  The Workspaces context.

  Handles workspace creation, management, and membership.
  This module follows Clean Architecture patterns by delegating to:
  - Query Objects (infrastructure layer) for data access
  - Policies (domain layer) for business rules
  """

  # Core context - cannot depend on JargaWeb (interface layer)
  # Exports: Main context module and shared types (Workspace)
  # Internal modules (WorkspaceMember, Queries, Policies) remain private
  use Boundary,
    top_level?: true,
    deps: [Jarga.Accounts, Jarga.Repo],
    exports: [{Workspace, []}]

  alias Jarga.Repo
  alias Jarga.Accounts.User
  alias Jarga.Workspaces.{Workspace, WorkspaceMember, Queries}
  alias Jarga.Workspaces.Policies.Authorization

  @doc """
  Returns the list of workspaces for a given user.

  Only returns non-archived workspaces where the user is a member.

  ## Examples

      iex> list_workspaces_for_user(user)
      [%Workspace{}, ...]

  """
  def list_workspaces_for_user(%User{} = user) do
    Queries.base()
    |> Queries.for_user(user)
    |> Queries.active()
    |> Queries.ordered()
    |> Repo.all()
  end

  @doc """
  Creates a workspace for a user.

  Automatically adds the creating user as an owner of the workspace.

  ## Examples

      iex> create_workspace(user, %{name: "My Workspace"})
      {:ok, %Workspace{}}

      iex> create_workspace(user, %{name: ""})
      {:error, %Ecto.Changeset{}}

  """
  def create_workspace(%User{} = user, attrs) do
    Repo.transact(fn ->
      with {:ok, workspace} <- create_workspace_record(attrs),
           {:ok, _member} <- add_member_as_owner(workspace, user) do
        {:ok, workspace}
      end
    end)
  end

  defp create_workspace_record(attrs) do
    %Workspace{}
    |> Workspace.changeset(attrs)
    |> Repo.insert()
  end

  defp add_member_as_owner(workspace, user) do
    %WorkspaceMember{}
    |> WorkspaceMember.changeset(%{
      workspace_id: workspace.id,
      user_id: user.id,
      email: user.email,
      role: :owner,
      joined_at: DateTime.utc_now()
    })
    |> Repo.insert()
  end

  @doc """
  Gets a single workspace for a user.

  Raises `Ecto.NoResultsError` if the Workspace does not exist or
  if the user is not a member of the workspace.

  ## Examples

      iex> get_workspace!(user, workspace_id)
      %Workspace{}

      iex> get_workspace!(user, "non-existent-id")
      ** (Ecto.NoResultsError)

  """
  def get_workspace!(%User{} = user, id) do
    Queries.for_user_by_id(user, id)
    |> Repo.one!()
  end

  @doc """
  Updates a workspace for a user.

  The user must be a member of the workspace to update it.

  ## Examples

      iex> update_workspace(user, workspace_id, %{name: "Updated Name"})
      {:ok, %Workspace{}}

      iex> update_workspace(user, workspace_id, %{name: ""})
      {:error, %Ecto.Changeset{}}

      iex> update_workspace(user, non_member_workspace_id, %{name: "Updated"})
      {:error, :unauthorized}

  """
  def update_workspace(%User{} = user, workspace_id, attrs) do
    case Authorization.verify_membership(user, workspace_id) do
      {:ok, workspace} ->
        workspace
        |> Workspace.changeset(attrs)
        |> Repo.update()

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes a workspace for a user.

  The user must be a member of the workspace to delete it.
  Deleting a workspace will cascade delete all associated projects.

  ## Examples

      iex> delete_workspace(user, workspace_id)
      {:ok, %Workspace{}}

      iex> delete_workspace(user, non_member_workspace_id)
      {:error, :unauthorized}

  """
  def delete_workspace(%User{} = user, workspace_id) do
    case Authorization.verify_membership(user, workspace_id) do
      {:ok, workspace} ->
        Repo.delete(workspace)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Verifies that a user is a member of a workspace.

  This is a public API for other contexts to verify workspace membership.

  ## Returns

  - `{:ok, workspace}` - User is a member of the workspace
  - `{:error, :unauthorized}` - Workspace exists but user is not a member
  - `{:error, :workspace_not_found}` - Workspace does not exist

  ## Examples

      iex> verify_membership(user, workspace_id)
      {:ok, %Workspace{}}

      iex> verify_membership(user, non_member_workspace_id)
      {:error, :unauthorized}

  """
  def verify_membership(%User{} = user, workspace_id) do
    Authorization.verify_membership(user, workspace_id)
  end
end
