defmodule Jarga.Workspaces.UseCases.InviteMember do
  @moduledoc """
  Use case for inviting a member to a workspace.

  This use case orchestrates the process of inviting a user to join a workspace,
  handling both existing users (immediate membership) and new users (pending invitations).

  ## Responsibilities

  - Validate inviter has permission
  - Validate role is allowed for invitation
  - Check if email is already a member
  - Add existing users as immediate members
  - Create pending invitations for new users
  - Send appropriate notifications

  ## Dependencies

  This use case accepts dependencies via options for testability:
  - `:notifier` - Module implementing notification callbacks
  """

  @behaviour Jarga.Workspaces.UseCases.UseCase

  import Ecto.Query, warn: false

  alias Jarga.Repo
  alias Jarga.Accounts
  alias Jarga.Workspaces.WorkspaceMember
  alias Jarga.Workspaces.Policies.MembershipPolicy
  alias Jarga.Workspaces.Infrastructure.MembershipRepository

  @doc """
  Executes the invite member use case.

  ## Parameters

  - `params` - Map containing:
    - `:inviter` - User performing the invitation
    - `:workspace_id` - ID of the workspace
    - `:email` - Email of the person to invite
    - `:role` - Role to assign (:admin, :member, or :guest)

  - `opts` - Keyword list of options:
    - `:notifier` - Optional notifier module (default: uses real notifier)

  ## Returns

  - `{:ok, {:member_added, member}}` - Existing user added successfully
  - `{:ok, {:invitation_sent, invitation}}` - Pending invitation created
  - `{:error, reason}` - Operation failed
  """
  @impl true
  def execute(params, opts \\ []) do
    %{
      inviter: inviter,
      workspace_id: workspace_id,
      email: email,
      role: role
    } = params

    notifier = Keyword.get(opts, :notifier)

    with :ok <- validate_role(role),
         {:ok, workspace} <- verify_inviter_membership(inviter, workspace_id),
         :ok <- check_not_already_member(workspace_id, email),
         user <- find_user_by_email_case_insensitive(email) do
      if user do
        add_existing_user_as_member(workspace, user, role, inviter, notifier)
      else
        create_pending_invitation(workspace, email, role, inviter, notifier)
      end
    end
  end

  # Apply domain policy: validate role is allowed for invitation
  defp validate_role(role) do
    if MembershipPolicy.valid_invitation_role?(role) do
      :ok
    else
      {:error, :invalid_role}
    end
  end

  # Use infrastructure repository: verify inviter is a member
  defp verify_inviter_membership(inviter, workspace_id) do
    case MembershipRepository.get_workspace_for_user(inviter, workspace_id) do
      nil ->
        # Check if workspace exists to provide meaningful error
        if MembershipRepository.workspace_exists?(workspace_id) do
          {:error, :unauthorized}
        else
          {:error, :workspace_not_found}
        end

      workspace ->
        {:ok, workspace}
    end
  end

  # Use infrastructure repository: check if email is already a member
  defp check_not_already_member(workspace_id, email) do
    if MembershipRepository.email_is_member?(workspace_id, email) do
      {:error, :already_member}
    else
      :ok
    end
  end

  defp find_user_by_email_case_insensitive(email) do
    # Delegate to Accounts context - fixed Credo violation
    Accounts.get_user_by_email_case_insensitive(email)
  end

  defp add_existing_user_as_member(workspace, user, role, inviter, notifier) do
    now = DateTime.utc_now()

    attrs = %{
      workspace_id: workspace.id,
      user_id: user.id,
      email: user.email,
      role: role,
      invited_by: inviter.id,
      invited_at: now,
      joined_at: now
    }

    case %WorkspaceMember{}
         |> WorkspaceMember.changeset(attrs)
         |> Repo.insert() do
      {:ok, member} ->
        # Send notifications if notifier is provided
        if notifier do
          notifier.notify_existing_user(user, workspace, inviter)
        end

        {:ok, {:member_added, member}}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp create_pending_invitation(workspace, email, role, inviter, notifier) do
    attrs = %{
      workspace_id: workspace.id,
      user_id: nil,
      email: email,
      role: role,
      invited_by: inviter.id,
      invited_at: DateTime.utc_now(),
      joined_at: nil
    }

    case %WorkspaceMember{}
         |> WorkspaceMember.changeset(attrs)
         |> Repo.insert() do
      {:ok, invitation} ->
        # Send notifications if notifier is provided
        if notifier do
          notifier.notify_new_user(email, workspace, inviter)
        end

        {:ok, {:invitation_sent, invitation}}

      {:error, changeset} ->
        {:error, changeset}
    end
  end
end
