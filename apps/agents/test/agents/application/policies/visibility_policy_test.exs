defmodule Agents.Application.Policies.VisibilityPolicyTest do
  use ExUnit.Case, async: true

  alias Agents.Application.Policies.VisibilityPolicy

  describe "can_view_agent?/3" do
    test "owner can always view their own agent (PRIVATE)" do
      agent = %{user_id: "user-123", visibility: "PRIVATE"}

      assert VisibilityPolicy.can_view_agent?(agent, "user-123", false)
    end

    test "owner can always view their own agent (SHARED)" do
      agent = %{user_id: "user-123", visibility: "SHARED"}

      assert VisibilityPolicy.can_view_agent?(agent, "user-123", true)
    end

    test "workspace member can view SHARED agent" do
      agent = %{user_id: "owner-123", visibility: "SHARED"}

      assert VisibilityPolicy.can_view_agent?(agent, "viewer-456", true)
    end

    test "non-workspace member cannot view SHARED agent" do
      agent = %{user_id: "owner-123", visibility: "SHARED"}

      refute VisibilityPolicy.can_view_agent?(agent, "viewer-456", false)
    end

    test "non-owner cannot view PRIVATE agent even as workspace member" do
      agent = %{user_id: "owner-123", visibility: "PRIVATE"}

      refute VisibilityPolicy.can_view_agent?(agent, "viewer-456", true)
    end

    test "non-owner non-member cannot view PRIVATE agent" do
      agent = %{user_id: "owner-123", visibility: "PRIVATE"}

      refute VisibilityPolicy.can_view_agent?(agent, "viewer-456", false)
    end
  end
end
