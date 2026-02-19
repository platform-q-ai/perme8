defmodule Identity.Application.UseCases.RemoveMember do
  @moduledoc """
  Use case for removing a member from a workspace.

  ## Business Rules

  - Actor must be a member of the workspace
  - Cannot remove the owner (owner is permanent)
  - Can remove active members and pending invitations

  ## Responsibilities

  - Validate actor has permission
  - Prevent removing the owner
  - Delete the workspace member record
  """

  @behaviour Identity.Application.UseCases.UseCase

  alias Identity.Domain.Entities.WorkspaceMember
  alias Identity.Domain.Events.MemberRemoved
  alias Identity.Domain.Policies.MembershipPolicy
  alias Identity.Domain.Policies.WorkspacePermissionsPolicy

  @default_membership_repository Identity.Infrastructure.Repositories.MembershipRepository
  @default_event_bus Perme8.Events.EventBus

  @doc """
  Executes the remove member use case.

  ## Parameters

  - `params` - Map containing:
    - `:actor` - User performing the removal
    - `:workspace_id` - ID of the workspace
    - `:member_email` - Email of the member to remove

  - `opts` - Keyword list of options

  ## Returns

  - `{:ok, deleted_member}` - Member removed successfully
  - `{:error, reason}` - Operation failed
  """
  @impl true
  def execute(params, opts \\ []) do
    %{
      actor: actor,
      workspace_id: workspace_id,
      member_email: member_email
    } = params

    membership_repository =
      Keyword.get(opts, :membership_repository, @default_membership_repository)

    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)

    with {:ok, workspace} <- verify_actor_membership(actor, workspace_id, membership_repository),
         {:ok, actor_member} <- get_actor_member(actor, workspace_id, membership_repository),
         :ok <- check_actor_permission(actor_member),
         {:ok, member} <- find_member(workspace_id, member_email, membership_repository),
         :ok <- validate_can_remove(member),
         {:ok, deleted_member} <- delete_member(member, membership_repository) do
      emit_member_removed_event(deleted_member, workspace, actor, event_bus)
      {:ok, deleted_member}
    end
  end

  # Use infrastructure repository: verify actor is a member
  defp verify_actor_membership(actor, workspace_id, membership_repository) do
    case membership_repository.get_workspace_for_user(actor, workspace_id) do
      nil ->
        if membership_repository.workspace_exists?(workspace_id) do
          {:error, :unauthorized}
        else
          {:error, :workspace_not_found}
        end

      workspace ->
        {:ok, workspace}
    end
  end

  # Get actor's membership record to check their role
  defp get_actor_member(actor, workspace_id, membership_repository) do
    case membership_repository.get_member(actor, workspace_id) do
      nil -> {:error, :unauthorized}
      member -> {:ok, member}
    end
  end

  # Check if actor has permission to remove members
  defp check_actor_permission(actor_member) do
    if WorkspacePermissionsPolicy.can?(actor_member.role, :remove_member) do
      :ok
    else
      {:error, :forbidden}
    end
  end

  # Use infrastructure repository: find member by email
  defp find_member(workspace_id, email, membership_repository) do
    case membership_repository.find_member_by_email(workspace_id, email) do
      nil -> {:error, :member_not_found}
      member -> {:ok, member}
    end
  end

  # Apply domain policy: validate member can be removed
  defp validate_can_remove(%WorkspaceMember{role: role}) do
    if MembershipPolicy.can_remove_member?(role) do
      :ok
    else
      {:error, :cannot_remove_owner}
    end
  end

  defp delete_member(member, membership_repository) do
    membership_repository.delete_member(member)
  end

  # Emit MemberRemoved event if the member had already joined (not just a pending invitation)
  defp emit_member_removed_event(
         %WorkspaceMember{user_id: user_id, joined_at: joined_at},
         workspace,
         actor,
         event_bus
       )
       when not is_nil(user_id) and not is_nil(joined_at) do
    event =
      MemberRemoved.new(%{
        aggregate_id: "#{workspace.id}:#{user_id}",
        actor_id: actor.id,
        workspace_id: workspace.id,
        target_user_id: user_id
      })

    event_bus.emit(event)
  end

  defp emit_member_removed_event(_member, _workspace, _actor, _event_bus), do: :ok
end
