defmodule Jarga.Agents.Policies.VisibilityPolicyTest do
  use ExUnit.Case, async: true

  alias Jarga.Agents.Policies.VisibilityPolicy

  describe "can_view_agent?/3" do
    test "returns true when user is owner" do
      agent = %{user_id: "user-123", visibility: "PRIVATE"}
      user_id = "user-123"
      workspace_member? = false

      assert VisibilityPolicy.can_view_agent?(agent, user_id, workspace_member?)
    end

    test "returns true when agent is SHARED and user is workspace member" do
      agent = %{user_id: "owner-123", visibility: "SHARED"}
      user_id = "viewer-456"
      workspace_member? = true

      assert VisibilityPolicy.can_view_agent?(agent, user_id, workspace_member?)
    end

    test "returns false when agent is PRIVATE and user is not owner" do
      agent = %{user_id: "owner-123", visibility: "PRIVATE"}
      user_id = "viewer-456"
      workspace_member? = true

      refute VisibilityPolicy.can_view_agent?(agent, user_id, workspace_member?)
    end

    test "returns false when agent is SHARED but user is not workspace member" do
      agent = %{user_id: "owner-123", visibility: "SHARED"}
      user_id = "viewer-456"
      workspace_member? = false

      refute VisibilityPolicy.can_view_agent?(agent, user_id, workspace_member?)
    end

    test "returns true when user is owner regardless of workspace membership" do
      agent = %{user_id: "user-123", visibility: "SHARED"}
      user_id = "user-123"
      workspace_member? = false

      assert VisibilityPolicy.can_view_agent?(agent, user_id, workspace_member?)
    end
  end
end
