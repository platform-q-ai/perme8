defmodule Jarga.Agents.Policies.AgentPolicyTest do
  use ExUnit.Case, async: true

  alias Jarga.Agents.Policies.AgentPolicy

  describe "can_edit?/2" do
    test "returns true when user is owner" do
      agent = %{user_id: "user-123"}
      user_id = "user-123"

      assert AgentPolicy.can_edit?(agent, user_id)
    end

    test "returns false when user is not owner" do
      agent = %{user_id: "owner-123"}
      user_id = "viewer-456"

      refute AgentPolicy.can_edit?(agent, user_id)
    end
  end

  describe "can_delete?/2" do
    test "returns true when user is owner" do
      agent = %{user_id: "user-123"}
      user_id = "user-123"

      assert AgentPolicy.can_delete?(agent, user_id)
    end

    test "returns false when user is not owner" do
      agent = %{user_id: "owner-123"}
      user_id = "viewer-456"

      refute AgentPolicy.can_delete?(agent, user_id)
    end
  end

  describe "can_clone?/3" do
    test "returns true when agent is SHARED and user is workspace member" do
      agent = %{user_id: "owner-123", visibility: "SHARED"}
      user_id = "viewer-456"
      workspace_member? = true

      assert AgentPolicy.can_clone?(agent, user_id, workspace_member?)
    end

    test "returns false when agent is PRIVATE" do
      agent = %{user_id: "owner-123", visibility: "PRIVATE"}
      user_id = "viewer-456"
      workspace_member? = true

      refute AgentPolicy.can_clone?(agent, user_id, workspace_member?)
    end

    test "returns false when user is not workspace member even if SHARED" do
      agent = %{user_id: "owner-123", visibility: "SHARED"}
      user_id = "viewer-456"
      workspace_member? = false

      refute AgentPolicy.can_clone?(agent, user_id, workspace_member?)
    end

    test "returns true when user is owner (can clone own agent)" do
      agent = %{user_id: "user-123", visibility: "PRIVATE"}
      user_id = "user-123"
      workspace_member? = false

      assert AgentPolicy.can_clone?(agent, user_id, workspace_member?)
    end

    test "returns true when owner and workspace member (SHARED)" do
      agent = %{user_id: "user-123", visibility: "SHARED"}
      user_id = "user-123"
      workspace_member? = true

      assert AgentPolicy.can_clone?(agent, user_id, workspace_member?)
    end
  end
end
