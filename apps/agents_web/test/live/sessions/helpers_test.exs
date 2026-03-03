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

  describe "format_duration/3" do
    test "returns nil when started_at is nil" do
      assert Helpers.format_duration(nil) == nil
      assert Helpers.format_duration(nil, ~U[2026-01-01 00:05:00Z]) == nil
    end

    test "formats seconds-only duration" do
      started = ~U[2026-01-01 00:00:00Z]
      completed = ~U[2026-01-01 00:00:45Z]
      assert Helpers.format_duration(started, completed) == "45s"
    end

    test "formats minutes and seconds" do
      started = ~U[2026-01-01 00:00:00Z]
      completed = ~U[2026-01-01 00:05:30Z]
      assert Helpers.format_duration(started, completed) == "5m 30s"
    end

    test "formats hours and minutes" do
      started = ~U[2026-01-01 00:00:00Z]
      completed = ~U[2026-01-01 01:05:00Z]
      assert Helpers.format_duration(started, completed) == "1h 5m"
    end

    test "formats days and hours" do
      started = ~U[2026-01-01 00:00:00Z]
      completed = ~U[2026-01-03 03:00:00Z]
      assert Helpers.format_duration(started, completed) == "2d 3h"
    end

    test "uses now for running sessions (completed_at nil)" do
      started = ~U[2026-01-01 00:00:00Z]
      now = ~U[2026-01-01 00:12:30Z]
      assert Helpers.format_duration(started, nil, now) == "12m 30s"
    end

    test "returns 0s for zero-duration" do
      t = ~U[2026-01-01 00:00:00Z]
      assert Helpers.format_duration(t, t) == "0s"
    end
  end

  describe "task_error_message/1" do
    test "formats auth refresh provider failures with HTTP body details" do
      reason =
        {:auth_refresh_failed,
         [
           %{provider: "openai", reason: {:http_error, 400, %{"error" => "invalid_grant"}}}
         ]}

      message = Helpers.task_error_message(reason)

      assert message =~ "Auth refresh failed"
      assert message =~ "openai"
      assert message =~ "HTTP 400"
      assert message =~ "invalid_grant"
    end
  end

  describe "format_file_stats/1" do
    test "returns nil for nil summary" do
      assert Helpers.format_file_stats(nil) == nil
    end

    test "returns nil for zero files" do
      assert Helpers.format_file_stats(%{"files" => 0, "additions" => 0, "deletions" => 0}) == nil
    end

    test "formats file stats with plural files" do
      summary = %{"files" => 3, "additions" => 42, "deletions" => 18}
      assert Helpers.format_file_stats(summary) == "3 files +42 -18"
    end

    test "formats file stats with singular file" do
      summary = %{"files" => 1, "additions" => 10, "deletions" => 5}
      assert Helpers.format_file_stats(summary) == "1 file +10 -5"
    end

    test "returns nil for unexpected format" do
      assert Helpers.format_file_stats(%{"something" => "else"}) == nil
      assert Helpers.format_file_stats("invalid") == nil
    end
  end

  describe "ticket_label_class/1" do
    test "maps known high-signal labels to daisyUI classes" do
      assert Helpers.ticket_label_class("bug") == "badge-error"
      assert Helpers.ticket_label_class("feature") == "badge-success"
      assert Helpers.ticket_label_class("docs") == "badge-accent"
      assert Helpers.ticket_label_class("refactor") == "badge-warning"
      assert Helpers.ticket_label_class("backend") == "badge-secondary"
      assert Helpers.ticket_label_class("frontend") == "badge-info"
      assert Helpers.ticket_label_class("agents") == "badge-primary"
    end

    test "normalizes casing and whitespace" do
      assert Helpers.ticket_label_class("  SECURITY ") == "badge-error"
      assert Helpers.ticket_label_class(" Documentation") == "badge-accent"
    end

    test "falls back to outline for unknown labels" do
      assert Helpers.ticket_label_class("something-custom") == "badge-outline"
      assert Helpers.ticket_label_class(nil) == "badge-outline"
    end
  end

  describe "ticket_size_class/1" do
    test "maps sizes to consistent badge classes" do
      assert Helpers.ticket_size_class("XL") == "badge-error text-white"
      assert Helpers.ticket_size_class("L") == "badge-warning"
      assert Helpers.ticket_size_class("M") == "badge-info"
      assert Helpers.ticket_size_class("S") == "badge-success"
      assert Helpers.ticket_size_class("XS") == "badge-ghost"
      assert Helpers.ticket_size_class(nil) == "badge-outline"
    end
  end
end
