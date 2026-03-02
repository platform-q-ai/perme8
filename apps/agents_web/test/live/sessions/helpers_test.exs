defmodule AgentsWeb.SessionsLive.HelpersTest do
  use ExUnit.Case, async: true

  alias AgentsWeb.SessionsLive.Helpers

  describe "auth_refreshing?/2" do
    test "returns true when task_id is in the map" do
      refreshing = %{"task-1" => make_ref()}
      assert Helpers.auth_refreshing?(refreshing, "task-1")
    end

    test "returns false when task_id is not in the map" do
      refreshing = %{"task-1" => make_ref()}
      refute Helpers.auth_refreshing?(refreshing, "task-2")
    end

    test "returns false for empty map" do
      refute Helpers.auth_refreshing?(%{}, "task-1")
    end

    test "returns false for non-map values" do
      refute Helpers.auth_refreshing?(nil, "task-1")
      refute Helpers.auth_refreshing?(false, "task-1")
      refute Helpers.auth_refreshing?(true, "task-1")
    end

    test "handles multiple concurrent refreshes" do
      refreshing = %{
        "task-1" => make_ref(),
        "task-2" => make_ref(),
        "task-3" => make_ref()
      }

      assert Helpers.auth_refreshing?(refreshing, "task-1")
      assert Helpers.auth_refreshing?(refreshing, "task-2")
      assert Helpers.auth_refreshing?(refreshing, "task-3")
      refute Helpers.auth_refreshing?(refreshing, "task-4")
    end
  end

  describe "has_auth_refresh_candidates?/1" do
    test "returns true when a session has failed status and auth error" do
      sessions = [
        %{latest_status: "failed", latest_error: "Token refresh failed: 400"}
      ]

      assert Helpers.has_auth_refresh_candidates?(sessions)
    end

    test "returns true for token expired error" do
      sessions = [
        %{latest_status: "failed", latest_error: "token expired"}
      ]

      assert Helpers.has_auth_refresh_candidates?(sessions)
    end

    test "returns true for authentication failed error" do
      sessions = [
        %{latest_status: "failed", latest_error: "authentication failed"}
      ]

      assert Helpers.has_auth_refresh_candidates?(sessions)
    end

    test "returns true for unauthorized error" do
      sessions = [
        %{latest_status: "failed", latest_error: "unauthorized"}
      ]

      assert Helpers.has_auth_refresh_candidates?(sessions)
    end

    test "returns false when no sessions" do
      refute Helpers.has_auth_refresh_candidates?([])
    end

    test "returns false when session failed with non-auth error" do
      sessions = [
        %{latest_status: "failed", latest_error: "Container start failed: timeout"}
      ]

      refute Helpers.has_auth_refresh_candidates?(sessions)
    end

    test "returns false when session is not failed" do
      sessions = [
        %{latest_status: "completed", latest_error: nil},
        %{latest_status: "running", latest_error: nil}
      ]

      refute Helpers.has_auth_refresh_candidates?(sessions)
    end

    test "returns false when latest_error is nil" do
      sessions = [
        %{latest_status: "failed", latest_error: nil}
      ]

      refute Helpers.has_auth_refresh_candidates?(sessions)
    end

    test "returns true when at least one session qualifies among many" do
      sessions = [
        %{latest_status: "completed", latest_error: nil},
        %{latest_status: "failed", latest_error: "Container start failed"},
        %{latest_status: "failed", latest_error: "Token refresh failed: 400"}
      ]

      assert Helpers.has_auth_refresh_candidates?(sessions)
    end
  end
end
