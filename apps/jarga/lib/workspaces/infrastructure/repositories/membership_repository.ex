defmodule Jarga.Workspaces.Infrastructure.Repositories.MembershipRepository do
  @moduledoc """
  Repository for workspace membership data access.

  This module is part of the infrastructure layer and handles all
  database queries related to workspace membership verification.

  Following Infrastructure Layer principles:
  - Encapsulates data access logic
  - Uses Ecto and Repo for database operations
  - Returns domain entities (WorkspaceMember, Workspace)
  - No business rules - just data retrieval
  """

  @behaviour Jarga.Workspaces.Application.Behaviours.MembershipRepositoryBehaviour

  import Ecto.Query, warn: false

  alias Jarga.Repo
  alias Jarga.Accounts.Domain.Entities.User
  alias Jarga.Workspaces.Infrastructure.Queries.Queries
  alias Jarga.Workspaces.Domain.Entities.{Workspace, WorkspaceMember}
  alias Jarga.Workspaces.Infrastructure.Schemas.{WorkspaceSchema, WorkspaceMemberSchema}

  @doc """
  Finds a workspace and verifies the user is a member.

  Returns the workspace if the user is a member, nil otherwise.

  ## Examples

      iex> get_workspace_for_user(user, workspace_id)
      %Workspace{}

      iex> get_workspace_for_user(non_member, workspace_id)
      nil

  """
  @impl true
  def get_workspace_for_user(%User{} = user, workspace_id, repo \\ Repo) do
    case Queries.for_user_by_id(user, workspace_id) |> repo.one() do
      nil -> nil
      schema -> Workspace.from_schema(schema)
    end
  end

  @doc """
  Finds a workspace by slug and verifies the user is a member.

  Returns the workspace if the user is a member, nil otherwise.

  ## Examples

      iex> get_workspace_for_user_by_slug(user, "my-workspace")
      %Workspace{}

      iex> get_workspace_for_user_by_slug(non_member, "my-workspace")
      nil

  """
  def get_workspace_for_user_by_slug(%User{} = user, slug, repo \\ Repo) do
    case Queries.for_user_by_slug(user, slug) |> repo.one() do
      nil -> nil
      schema -> Workspace.from_schema(schema)
    end
  end

  @doc """
  Finds a workspace by slug with the current user's member record preloaded.

  Returns a tuple of {workspace, member} if the user is a member, nil otherwise.
  This is more efficient than calling get_workspace_for_user_by_slug/2 followed
  by get_member/2 as it uses a single query instead of two.

  ## Examples

      iex> get_workspace_and_member_by_slug(user, "my-workspace")
      {%Workspace{}, %WorkspaceMember{}}

      iex> get_workspace_and_member_by_slug(non_member, "my-workspace")
      nil

  """
  def get_workspace_and_member_by_slug(%User{} = user, slug, repo \\ Repo) do
    case Queries.for_user_by_slug_with_member(user, slug) |> repo.one() do
      nil ->
        nil

      schema ->
        # Convert workspace to domain entity
        workspace = Workspace.from_schema(schema)
        # Member conversion
        member_schema = List.first(schema.workspace_members)
        member = if member_schema, do: WorkspaceMember.from_schema(member_schema), else: nil
        {workspace, member}
    end
  end

  @doc """
  Checks if a workspace exists.

  ## Examples

      iex> workspace_exists?(workspace_id)
      true

      iex> workspace_exists?(invalid_id)
      false

  """
  @impl true
  def workspace_exists?(workspace_id, repo \\ Repo) do
    case Queries.exists?(workspace_id) |> repo.one() do
      count when count > 0 -> true
      _ -> false
    end
  end

  @doc """
  Gets a user's workspace member record.

  ## Examples

      iex> get_member(user, workspace_id)
      %WorkspaceMember{role: :owner}

      iex> get_member(non_member, workspace_id)
      nil

  """
  def get_member(%User{} = user, workspace_id, repo \\ Repo) do
    case Queries.get_member(user, workspace_id) |> repo.one() do
      nil -> nil
      schema -> WorkspaceMember.from_schema(schema)
    end
  end

  @doc """
  Finds a workspace member by email (case-insensitive).

  ## Examples

      iex> find_member_by_email(workspace_id, "user@example.com")
      %WorkspaceMember{}

      iex> find_member_by_email(workspace_id, "nonexistent@example.com")
      nil

  """
  @impl true
  def find_member_by_email(workspace_id, email, repo \\ Repo) do
    case Queries.find_member_by_email(workspace_id, email) |> repo.one() do
      nil -> nil
      schema -> WorkspaceMember.from_schema(schema)
    end
  end

  @doc """
  Checks if an email is already a member of a workspace.

  ## Examples

      iex> email_is_member?(workspace_id, "member@example.com")
      true

      iex> email_is_member?(workspace_id, "new@example.com")
      false

  """
  def email_is_member?(workspace_id, email, repo \\ Repo) do
    case find_member_by_email(workspace_id, email, repo) do
      nil -> false
      _member -> true
    end
  end

  @doc """
  Lists all members of a workspace.

  ## Examples

      iex> list_members(workspace_id)
      [%WorkspaceMember{}, ...]

  """
  def list_members(workspace_id, repo \\ Repo) do
    Queries.list_members(workspace_id)
    |> repo.all()
    |> Enum.map(&WorkspaceMember.from_schema/1)
  end

  @doc """
  Checks if a workspace slug already exists.

  ## Examples

      iex> slug_exists?("my-workspace", nil)
      true

      iex> slug_exists?("new-slug", nil)
      false

  """
  def slug_exists?(slug, excluding_id \\ nil, repo \\ Repo) do
    import Ecto.Query

    query =
      from(w in WorkspaceSchema,
        where: w.slug == ^slug
      )

    query =
      if excluding_id do
        from(w in query, where: w.id != ^excluding_id)
      else
        query
      end

    repo.exists?(query)
  end

  @doc """
  Updates a workspace member's role directly (for testing).
  """
  def update_role(workspace_id, email, role, repo \\ Repo) do
    import Ecto.Query

    query =
      from(m in WorkspaceMemberSchema,
        where: m.workspace_id == ^workspace_id and m.email == ^email
      )

    repo.update_all(query, set: [role: role, updated_at: DateTime.utc_now()])
  end

  @doc """
  Adds a member to a workspace (for testing purposes).

  ## Parameters
    - workspace_id: ID of the workspace
    - user_id: ID of the user to add
    - email: User's email
    - role: Member role (:owner, :admin, or :member)

  ## Returns
    - `{:ok, workspace_member}` if successful
    - `{:error, changeset}` if validation fails

  ## Examples

      iex> add_member(workspace_id, user_id, "user@example.com", :member)
      {:ok, %WorkspaceMember{}}

  """
  def add_member(workspace_id, user_id, email, role, repo \\ Repo) do
    %WorkspaceMemberSchema{}
    |> WorkspaceMemberSchema.changeset(%{
      workspace_id: workspace_id,
      user_id: user_id,
      email: email,
      role: role
    })
    |> repo.insert()
    |> case do
      {:ok, schema} -> {:ok, WorkspaceMember.from_schema(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Checks if a user is a member of a workspace by workspace ID.

  ## Examples

      iex> member?(user_id, workspace_id)
      true

      iex> member?(user_id, other_workspace_id)
      false

  """
  def member?(user_id, workspace_id, repo \\ Repo) do
    query =
      from(wm in WorkspaceMemberSchema,
        where: wm.user_id == ^user_id and wm.workspace_id == ^workspace_id
      )

    repo.exists?(query)
  end

  @doc """
  Checks if a user is a member of a workspace by workspace slug.

  ## Examples

      iex> member_by_slug?(user_id, "product-team")
      true

      iex> member_by_slug?(user_id, "other-workspace")
      false

  """
  def member_by_slug?(user_id, workspace_slug, repo \\ Repo) do
    query =
      from(wm in WorkspaceMemberSchema,
        join: w in WorkspaceSchema,
        on: w.id == wm.workspace_id,
        where: wm.user_id == ^user_id and w.slug == ^workspace_slug
      )

    repo.exists?(query)
  end

  @doc """
  Creates a new workspace member.

  ## Examples

      iex> create_member(%{workspace_id: id, email: "user@example.com", role: :member})
      {:ok, %WorkspaceMember{}}

      iex> create_member(%{})
      {:error, %Ecto.Changeset{}}

  """
  def create_member(attrs, repo \\ Repo) do
    %WorkspaceMemberSchema{}
    |> WorkspaceMemberSchema.changeset(attrs)
    |> repo.insert()
    |> case do
      {:ok, schema} -> {:ok, WorkspaceMember.from_schema(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Updates a workspace member.

  ## Examples

      iex> update_member(member, %{role: :admin})
      {:ok, %WorkspaceMember{}}

      iex> update_member(member, %{role: :invalid})
      {:error, %Ecto.Changeset{}}

  """
  @impl true
  def update_member(%WorkspaceMember{} = member, attrs, repo \\ Repo) do
    member
    |> WorkspaceMemberSchema.to_schema()
    |> WorkspaceMemberSchema.changeset(attrs)
    |> repo.update()
    |> case do
      {:ok, schema} -> {:ok, WorkspaceMember.from_schema(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Deletes a workspace member.

  ## Examples

      iex> delete_member(member)
      {:ok, %WorkspaceMember{}}

      iex> delete_member(invalid_member)
      {:error, %Ecto.Changeset{}}

  """
  @impl true
  def delete_member(%WorkspaceMember{} = member, repo \\ Repo) do
    member
    |> WorkspaceMemberSchema.to_schema()
    |> repo.delete()
    |> case do
      {:ok, schema} -> {:ok, WorkspaceMember.from_schema(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Executes a transaction with unwrapping support.
  This allows use cases to run database operations in a transaction
  without directly depending on Repo.
  """
  @impl true
  def transact(fun) when is_function(fun, 0) do
    Repo.transact(fun)
  end
end
