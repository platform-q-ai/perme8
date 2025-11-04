defmodule Jarga.Workspaces.Policies.Authorization do
  @moduledoc """
  Authorization policy for workspace access control.

  This module encapsulates business rules for determining whether a user
  has access to perform operations on workspaces.

  Following the Domain Layer pattern, this module contains pure business logic
  without dependencies on infrastructure (Ecto, Repo, etc.).
  """

  alias Jarga.Accounts.User
  alias Jarga.Workspaces.Queries
  alias Jarga.Repo

  @doc """
  Verifies that a user is a member of a workspace.

  Returns `{:ok, workspace}` if the user is a member, or an error tuple otherwise.

  ## Returns

  - `{:ok, workspace}` - User is a member of the workspace
  - `{:error, :unauthorized}` - Workspace exists but user is not a member
  - `{:error, :workspace_not_found}` - Workspace does not exist

  ## Examples

      iex> verify_membership(user, workspace_id)
      {:ok, %Workspace{}}

      iex> verify_membership(user, non_member_workspace_id)
      {:error, :unauthorized}

      iex> verify_membership(user, invalid_id)
      {:error, :workspace_not_found}

  """
  def verify_membership(%User{} = user, workspace_id, repo \\ Repo) do
    case Queries.for_user_by_id(user, workspace_id) |> repo.one() do
      nil ->
        # Check if workspace exists to provide meaningful error
        if workspace_exists?(workspace_id, repo) do
          {:error, :unauthorized}
        else
          {:error, :workspace_not_found}
        end

      workspace ->
        {:ok, workspace}
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
  def workspace_exists?(workspace_id, repo \\ Repo) do
    case Queries.exists?(workspace_id) |> repo.one() do
      count when count > 0 -> true
      _ -> false
    end
  end
end
