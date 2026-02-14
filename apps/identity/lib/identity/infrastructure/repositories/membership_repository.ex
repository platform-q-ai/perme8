defmodule Identity.Infrastructure.Repositories.MembershipRepository do
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

  import Ecto.Query, warn: false

  alias Identity.Repo
  alias Identity.Domain.Entities.User
  alias Identity.Domain.Entities.{Workspace, WorkspaceMember}
  alias Identity.Infrastructure.Queries.WorkspaceQueries, as: Queries
  alias Identity.Infrastructure.Schemas.{WorkspaceSchema, WorkspaceMemberSchema}

  @doc """
  Finds a workspace and verifies the user is a member.

  Returns the workspace if the user is a member, nil otherwise.
  """
  def get_workspace_for_user(%User{} = user, workspace_id, repo \\ Repo) do
    case Queries.for_user_by_id(user, workspace_id) |> repo.one() do
      nil -> nil
      schema -> Workspace.from_schema(schema)
    end
  end

  @doc """
  Finds a workspace by slug and verifies the user is a member.

  Returns the workspace if the user is a member, nil otherwise.
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
  """
  def get_workspace_and_member_by_slug(%User{} = user, slug, repo \\ Repo) do
    case Queries.for_user_by_slug_with_member(user, slug) |> repo.one() do
      nil ->
        nil

      schema ->
        workspace = Workspace.from_schema(schema)
        member_schema = List.first(schema.workspace_members)
        member = if member_schema, do: WorkspaceMember.from_schema(member_schema), else: nil
        {workspace, member}
    end
  end

  @doc """
  Checks if a workspace exists.
  """
  def workspace_exists?(workspace_id, repo \\ Repo) do
    case Queries.exists?(workspace_id) |> repo.one() do
      count when count > 0 -> true
      _ -> false
    end
  end

  @doc """
  Gets a user's workspace member record.
  """
  def get_member(%User{} = user, workspace_id, repo \\ Repo) do
    case Queries.get_member(user, workspace_id) |> repo.one() do
      nil -> nil
      schema -> WorkspaceMember.from_schema(schema)
    end
  end

  @doc """
  Finds a workspace member by email (case-insensitive).
  """
  def find_member_by_email(workspace_id, email, repo \\ Repo) do
    case Queries.find_member_by_email(workspace_id, email) |> repo.one() do
      nil -> nil
      schema -> WorkspaceMember.from_schema(schema)
    end
  end

  @doc """
  Checks if an email is already a member of a workspace.
  """
  def email_is_member?(workspace_id, email, repo \\ Repo) do
    case find_member_by_email(workspace_id, email, repo) do
      nil -> false
      _member -> true
    end
  end

  @doc """
  Lists all members of a workspace.
  """
  def list_members(workspace_id, repo \\ Repo) do
    Queries.list_members(workspace_id)
    |> repo.all()
    |> Enum.map(&WorkspaceMember.from_schema/1)
  end

  @doc """
  Checks if a workspace slug already exists.
  """
  def slug_exists?(slug, excluding_id \\ nil, repo \\ Repo) do
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
    query =
      from(m in WorkspaceMemberSchema,
        where: m.workspace_id == ^workspace_id and m.email == ^email
      )

    repo.update_all(query, set: [role: role, updated_at: DateTime.utc_now()])
  end

  @doc """
  Adds a member to a workspace (for testing purposes).
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
  """
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
  """
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
  """
  def transact(fun) when is_function(fun, 0) do
    Repo.transact(fun)
  end
end
