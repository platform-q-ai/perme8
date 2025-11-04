defmodule Jarga.Workspaces.UseCases.ChangeMemberRole do
  @moduledoc """
  Use case for changing a workspace member's role.

  ## Business Rules

  - Actor must be a member of the workspace
  - Cannot change owner's role (owner is permanent)
  - Cannot assign owner role (only one owner per workspace)
  - Can change between admin, member, and guest roles

  ## Responsibilities

  - Validate actor has permission
  - Validate target role is allowed
  - Prevent changing owner's role
  - Update member's role in database
  """

  @behaviour Jarga.Workspaces.UseCases.UseCase

  alias Jarga.Repo
  alias Jarga.Workspaces.WorkspaceMember
  alias Jarga.Workspaces.Policies.MembershipPolicy
  alias Jarga.Workspaces.Infrastructure.MembershipRepository

  @doc """
  Executes the change member role use case.

  ## Parameters

  - `params` - Map containing:
    - `:actor` - User performing the role change
    - `:workspace_id` - ID of the workspace
    - `:member_email` - Email of the member whose role to change
    - `:new_role` - New role to assign (:admin, :member, or :guest)

  - `opts` - Keyword list of options (currently unused)

  ## Returns

  - `{:ok, updated_member}` - Role changed successfully
  - `{:error, reason}` - Operation failed
  """
  @impl true
  def execute(params, _opts \\ []) do
    %{
      actor: actor,
      workspace_id: workspace_id,
      member_email: member_email,
      new_role: new_role
    } = params

    with :ok <- validate_role(new_role),
         {:ok, _workspace} <- verify_actor_membership(actor, workspace_id),
         {:ok, member} <- find_member(workspace_id, member_email),
         :ok <- validate_can_change_role(member) do
      update_member_role(member, new_role)
    end
  end

  # Apply domain policy: validate role is allowed for role changes
  defp validate_role(role) do
    if MembershipPolicy.valid_role_change?(role) do
      :ok
    else
      {:error, :invalid_role}
    end
  end

  # Use infrastructure repository: verify actor is a member
  defp verify_actor_membership(actor, workspace_id) do
    case MembershipRepository.get_workspace_for_user(actor, workspace_id) do
      nil ->
        if MembershipRepository.workspace_exists?(workspace_id) do
          {:error, :unauthorized}
        else
          {:error, :workspace_not_found}
        end

      workspace ->
        {:ok, workspace}
    end
  end

  # Use infrastructure repository: find member by email
  defp find_member(workspace_id, email) do
    case MembershipRepository.find_member_by_email(workspace_id, email) do
      nil -> {:error, :member_not_found}
      member -> {:ok, member}
    end
  end

  # Apply domain policy: validate member's role can be changed
  defp validate_can_change_role(%WorkspaceMember{role: role}) do
    if MembershipPolicy.can_change_role?(role) do
      :ok
    else
      {:error, :cannot_change_owner_role}
    end
  end

  defp update_member_role(member, new_role) do
    member
    |> WorkspaceMember.changeset(%{role: new_role})
    |> Repo.update()
  end
end
