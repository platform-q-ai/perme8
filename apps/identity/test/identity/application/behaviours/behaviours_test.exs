defmodule Identity.Application.Behaviours.BehavioursTest do
  use ExUnit.Case, async: true

  alias Identity.Application.Behaviours.MembershipRepositoryBehaviour
  alias Identity.Application.Behaviours.WorkspaceNotifierBehaviour
  alias Identity.Application.Behaviours.WorkspaceQueriesBehaviour

  describe "MembershipRepositoryBehaviour" do
    test "defines get_workspace_for_user/2 callback" do
      callbacks = MembershipRepositoryBehaviour.behaviour_info(:callbacks)
      assert {:get_workspace_for_user, 2} in callbacks
    end

    test "defines workspace_exists?/1 callback" do
      callbacks = MembershipRepositoryBehaviour.behaviour_info(:callbacks)
      assert {:workspace_exists?, 1} in callbacks
    end

    test "defines find_member_by_email/2 callback" do
      callbacks = MembershipRepositoryBehaviour.behaviour_info(:callbacks)
      assert {:find_member_by_email, 2} in callbacks
    end

    test "defines email_is_member?/2 callback" do
      callbacks = MembershipRepositoryBehaviour.behaviour_info(:callbacks)
      assert {:email_is_member?, 2} in callbacks
    end

    test "defines get_member/2 callback" do
      callbacks = MembershipRepositoryBehaviour.behaviour_info(:callbacks)
      assert {:get_member, 2} in callbacks
    end

    test "defines update_member/2 callback" do
      callbacks = MembershipRepositoryBehaviour.behaviour_info(:callbacks)
      assert {:update_member, 2} in callbacks
    end

    test "defines delete_member/1 callback" do
      callbacks = MembershipRepositoryBehaviour.behaviour_info(:callbacks)
      assert {:delete_member, 1} in callbacks
    end

    test "defines create_member/1 callback" do
      callbacks = MembershipRepositoryBehaviour.behaviour_info(:callbacks)
      assert {:create_member, 1} in callbacks
    end

    test "defines transact/1 callback" do
      callbacks = MembershipRepositoryBehaviour.behaviour_info(:callbacks)
      assert {:transact, 1} in callbacks
    end
  end

  describe "WorkspaceNotifierBehaviour" do
    test "defines notify_existing_user/3 callback" do
      callbacks = WorkspaceNotifierBehaviour.behaviour_info(:callbacks)
      assert {:notify_existing_user, 3} in callbacks
    end

    test "defines notify_new_user/3 callback" do
      callbacks = WorkspaceNotifierBehaviour.behaviour_info(:callbacks)
      assert {:notify_new_user, 3} in callbacks
    end
  end

  describe "WorkspaceQueriesBehaviour" do
    test "defines find_pending_invitations_by_email/1 callback" do
      callbacks = WorkspaceQueriesBehaviour.behaviour_info(:callbacks)
      assert {:find_pending_invitations_by_email, 1} in callbacks
    end

    test "defines with_workspace_and_inviter/1 callback" do
      callbacks = WorkspaceQueriesBehaviour.behaviour_info(:callbacks)
      assert {:with_workspace_and_inviter, 1} in callbacks
    end
  end
end
