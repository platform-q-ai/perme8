defmodule Jarga.Workspaces.Application.UseCases.RemoveMember do
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

  @behaviour Jarga.Workspaces.Application.UseCases.UseCase

  alias Jarga.Workspaces.Domain.Entities.WorkspaceMember
  alias Jarga.Workspaces.Domain.Policies.MembershipPolicy
  alias Jarga.Workspaces.Application.Policies.MembershipPolicy

  @default_membership_repository Jarga.Workspaces.Infrastructure.Repositories.MembershipRepository
  @default_notifier Jarga.Workspaces.Infrastructure.Notifiers.EmailAndPubSubNotifier

  @doc """
  Executes the remove member use case.

  ## Parameters

  - `params` - Map containing:
    - `:actor` - User performing the removal
    - `:workspace_id` - ID of the workspace
    - `:member_email` - Email of the member to remove

  - `opts` - Keyword list of options:
    - `:notifier` - Notification service implementation (default: EmailAndPubSubNotifier)

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

    notifier = Keyword.get(opts, :notifier, @default_notifier)

    with {:ok, workspace} <- verify_actor_membership(actor, workspace_id, membership_repository),
         {:ok, member} <- find_member(workspace_id, member_email, membership_repository),
         :ok <- validate_can_remove(member),
         {:ok, deleted_member} <- delete_member(member, membership_repository) do
      notify_user_if_joined(deleted_member, workspace, notifier)
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

  # Notify user if they had already joined (not just a pending invitation)
  defp notify_user_if_joined(
         %WorkspaceMember{user_id: user_id, joined_at: joined_at},
         workspace,
         notifier
       )
       when not is_nil(user_id) and not is_nil(joined_at) do
    # Fetch the user and notify (don't fail if user not found)
    user = Jarga.Accounts.get_user!(user_id)
    notifier.notify_user_removed(user, workspace)
  rescue
    Ecto.NoResultsError -> :ok
  end

  defp notify_user_if_joined(_member, _workspace, _notifier), do: :ok
end
