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

  describe "lane_status_label/1" do
    test "returns human-readable lane labels" do
      assert Helpers.lane_status_label(:processing) == "Processing"
      assert Helpers.lane_status_label(:warm) == "Warm"
      assert Helpers.lane_status_label(:cold) == "Cold"
      assert Helpers.lane_status_label(:awaiting_feedback) == "Awaiting Feedback"
      assert Helpers.lane_status_label(:retry_pending) == "Retry Pending"
    end

    test "returns Unknown for unsupported lanes" do
      assert Helpers.lane_status_label(:something_else) == "Unknown"
    end
  end

  describe "lane_css_class/1" do
    test "returns lane css classes" do
      assert Helpers.lane_css_class(:processing) == "lane-processing"
      assert Helpers.lane_css_class(:warm) == "lane-warm"
      assert Helpers.lane_css_class(:cold) == "lane-cold"
      assert Helpers.lane_css_class(:awaiting_feedback) == "lane-awaiting-feedback"
      assert Helpers.lane_css_class(:retry_pending) == "lane-retry-pending"
    end

    test "returns empty class for unsupported lanes" do
      assert Helpers.lane_css_class(:something_else) == ""
    end
  end

  describe "ticket_session_state_class/1" do
    test "maps lifecycle states to expected badge classes" do
      assert Helpers.ticket_session_state_class("running") == "badge-success"
      assert Helpers.ticket_session_state_class("queued_cold") == "badge-info"
      assert Helpers.ticket_session_state_class("queued_warm") == "badge-info"
      assert Helpers.ticket_session_state_class("pending") == "badge-info"
      assert Helpers.ticket_session_state_class("starting") == "badge-info"
      assert Helpers.ticket_session_state_class("warming") == "badge-warning"
      assert Helpers.ticket_session_state_class("awaiting_feedback") == "badge-warning"
      assert Helpers.ticket_session_state_class("completed") == "badge-primary"
      assert Helpers.ticket_session_state_class("failed") == "badge-error"
      assert Helpers.ticket_session_state_class("cancelled") == "badge-ghost"
      assert Helpers.ticket_session_state_class("idle") == "badge-ghost"
      assert Helpers.ticket_session_state_class("unknown") == "badge-ghost"
    end
  end

  describe "filter_sessions_by_search/2" do
    test "returns all sessions when query is empty" do
      sessions = [%{title: "Fix login"}, %{title: "Add tests"}]
      assert Helpers.filter_sessions_by_search(sessions, "") == sessions
    end

    test "returns all sessions when query is nil" do
      sessions = [%{title: "Fix login"}]
      assert Helpers.filter_sessions_by_search(sessions, nil) == sessions
    end

    test "filters sessions by title match (case-insensitive)" do
      sessions = [
        %{title: "Fix login bug"},
        %{title: "Add test coverage"},
        %{title: "Refactor LOGIN flow"}
      ]

      result = Helpers.filter_sessions_by_search(sessions, "login")
      assert length(result) == 2
      assert Enum.all?(result, fn s -> String.downcase(s.title) =~ "login" end)
    end

    test "returns empty list when nothing matches" do
      sessions = [%{title: "Fix login"}, %{title: "Add tests"}]
      assert Helpers.filter_sessions_by_search(sessions, "deploy") == []
    end

    test "handles sessions with nil title" do
      sessions = [%{title: nil}, %{title: "Fix login"}]
      result = Helpers.filter_sessions_by_search(sessions, "login")
      assert length(result) == 1
      assert hd(result).title == "Fix login"
    end

    test "matches partial strings" do
      sessions = [%{title: "pick up ticket #306 using the relevant skill"}]
      assert length(Helpers.filter_sessions_by_search(sessions, "306")) == 1
      assert length(Helpers.filter_sessions_by_search(sessions, "ticket")) == 1
      assert length(Helpers.filter_sessions_by_search(sessions, "SKILL")) == 1
    end
  end

  describe "filter_tickets_by_search/2" do
    test "returns all tickets when query is empty" do
      tickets = [%{title: "Bug", number: 1, labels: []}]
      assert Helpers.filter_tickets_by_search(tickets, "") == tickets
    end

    test "returns all tickets when query is nil" do
      tickets = [%{title: "Bug", number: 1, labels: []}]
      assert Helpers.filter_tickets_by_search(tickets, nil) == tickets
    end

    test "matches by title (case-insensitive)" do
      tickets = [
        %{title: "Fix login page", number: 1, labels: [], sub_tickets: []},
        %{title: "Add dark mode", number: 2, labels: [], sub_tickets: []}
      ]

      result = Helpers.filter_tickets_by_search(tickets, "login")
      assert length(result) == 1
      assert hd(result).number == 1
    end

    test "matches by ticket number" do
      tickets = [
        %{title: "Bug A", number: 42, labels: [], sub_tickets: []},
        %{title: "Bug B", number: 123, labels: [], sub_tickets: []}
      ]

      result = Helpers.filter_tickets_by_search(tickets, "42")
      assert length(result) == 1
      assert hd(result).number == 42
    end

    test "number match is exact, not substring" do
      tickets = [
        %{title: "Bug A", number: 1, labels: [], sub_tickets: []},
        %{title: "Bug B", number: 10, labels: [], sub_tickets: []},
        %{title: "Bug C", number: 100, labels: [], sub_tickets: []}
      ]

      result = Helpers.filter_tickets_by_search(tickets, "1")
      assert length(result) == 1
      assert hd(result).number == 1
    end

    test "matches by label" do
      tickets = [
        %{title: "Bug A", number: 1, labels: ["frontend", "urgent"], sub_tickets: []},
        %{title: "Bug B", number: 2, labels: ["backend"], sub_tickets: []}
      ]

      result = Helpers.filter_tickets_by_search(tickets, "frontend")
      assert length(result) == 1
      assert hd(result).number == 1
    end

    test "matches across title, number, and labels" do
      tickets = [
        %{title: "Fix login", number: 10, labels: ["bug"], sub_tickets: []},
        %{title: "Something else", number: 100, labels: ["enhancement"], sub_tickets: []},
        %{title: "Another task", number: 3, labels: ["login-related"], sub_tickets: []}
      ]

      result = Helpers.filter_tickets_by_search(tickets, "login")
      assert length(result) == 2
      numbers = Enum.map(result, & &1.number)
      assert 10 in numbers
      assert 3 in numbers
    end

    test "returns empty list when nothing matches" do
      tickets = [%{title: "Bug", number: 1, labels: ["frontend"], sub_tickets: []}]
      assert Helpers.filter_tickets_by_search(tickets, "deploy") == []
    end

    test "handles nil title and nil labels gracefully" do
      tickets = [%{title: nil, number: 5, labels: nil, sub_tickets: []}]
      result = Helpers.filter_tickets_by_search(tickets, "5")
      assert length(result) == 1
    end

    test "handles nil title and nil labels without crash on non-number query" do
      tickets = [%{title: nil, number: 5, labels: nil, sub_tickets: []}]
      result = Helpers.filter_tickets_by_search(tickets, "nonexistent")
      assert result == []
    end

    test "surfaces parent when a sub-ticket matches the search" do
      tickets = [
        %{
          title: "Parent ticket",
          number: 10,
          labels: [],
          sub_tickets: [
            %{title: "Child login fix", number: 11, labels: [], sub_tickets: []}
          ]
        },
        %{title: "Unrelated", number: 20, labels: [], sub_tickets: []}
      ]

      result = Helpers.filter_tickets_by_search(tickets, "login")
      assert length(result) == 1
      assert hd(result).number == 10
      assert length(hd(result).sub_tickets) == 1
      assert hd(hd(result).sub_tickets).number == 11
    end

    test "surfaces parent when a deeply nested sub-ticket matches the search" do
      tickets = [
        %{
          title: "Grandparent",
          number: 1,
          labels: [],
          sub_tickets: [
            %{
              title: "Parent",
              number: 2,
              labels: [],
              sub_tickets: [
                %{title: "Deep auth fix", number: 3, labels: [], sub_tickets: []}
              ]
            }
          ]
        }
      ]

      result = Helpers.filter_tickets_by_search(tickets, "auth")
      assert length(result) == 1
      assert hd(result).number == 1
      child = hd(hd(result).sub_tickets)
      assert child.number == 2
      assert hd(child.sub_tickets).number == 3
    end

    test "filters non-matching sub-tickets when searching" do
      tickets = [
        %{
          title: "Parent",
          number: 10,
          labels: [],
          sub_tickets: [
            %{title: "Matching login", number: 11, labels: [], sub_tickets: []},
            %{title: "Unrelated work", number: 12, labels: [], sub_tickets: []}
          ]
        }
      ]

      result = Helpers.filter_tickets_by_search(tickets, "login")
      assert length(result) == 1
      # Parent is kept because it has a matching sub-ticket
      parent = hd(result)
      assert parent.number == 10
      # Only the matching sub-ticket is included
      assert length(parent.sub_tickets) == 1
      assert hd(parent.sub_tickets).number == 11
    end

    test "matches by sub-ticket number" do
      tickets = [
        %{
          title: "Parent",
          number: 10,
          labels: [],
          sub_tickets: [
            %{title: "Sub A", number: 392, labels: [], sub_tickets: []}
          ]
        }
      ]

      result = Helpers.filter_tickets_by_search(tickets, "392")
      assert length(result) == 1
      assert hd(hd(result).sub_tickets).number == 392
    end

    test "matches by sub-ticket label" do
      tickets = [
        %{
          title: "Parent",
          number: 10,
          labels: [],
          sub_tickets: [
            %{title: "Sub", number: 11, labels: ["agents"], sub_tickets: []}
          ]
        }
      ]

      result = Helpers.filter_tickets_by_search(tickets, "agents")
      assert length(result) == 1
      assert hd(hd(result).sub_tickets).number == 11
    end

    test "parent matches search independently of sub-tickets" do
      tickets = [
        %{
          title: "Login feature",
          number: 10,
          labels: [],
          sub_tickets: [
            %{title: "Unrelated sub", number: 11, labels: [], sub_tickets: []}
          ]
        }
      ]

      result = Helpers.filter_tickets_by_search(tickets, "login")
      assert length(result) == 1
      assert hd(result).number == 10
      # Sub-tickets that don't match are pruned
      assert hd(result).sub_tickets == []
    end
  end

  describe "filter_sessions_by_status/2" do
    test "returns all sessions when status is :all" do
      sessions = [
        %{latest_status: "running"},
        %{latest_status: "completed"},
        %{latest_status: "failed"}
      ]

      assert Helpers.filter_sessions_by_status(sessions, :all) == sessions
    end

    test "filters by exact status" do
      sessions = [
        %{latest_status: "completed"},
        %{latest_status: "failed"},
        %{latest_status: "cancelled"}
      ]

      result = Helpers.filter_sessions_by_status(sessions, :completed)
      assert length(result) == 1
      assert hd(result).latest_status == "completed"
    end

    test ":running matches pending, starting, and running statuses" do
      sessions = [
        %{latest_status: "pending"},
        %{latest_status: "starting"},
        %{latest_status: "running"},
        %{latest_status: "completed"},
        %{latest_status: "queued"}
      ]

      result = Helpers.filter_sessions_by_status(sessions, :running)
      assert length(result) == 3
      statuses = Enum.map(result, & &1.latest_status)
      assert "pending" in statuses
      assert "starting" in statuses
      assert "running" in statuses
    end

    test "filters queued sessions" do
      sessions = [
        %{latest_status: "queued"},
        %{latest_status: "running"},
        %{latest_status: "queued"}
      ]

      result = Helpers.filter_sessions_by_status(sessions, :queued)
      assert length(result) == 2
    end

    test "filters awaiting_feedback sessions" do
      sessions = [
        %{latest_status: "awaiting_feedback"},
        %{latest_status: "completed"}
      ]

      result = Helpers.filter_sessions_by_status(sessions, :awaiting_feedback)
      assert length(result) == 1
      assert hd(result).latest_status == "awaiting_feedback"
    end

    test "returns empty list when no sessions match" do
      sessions = [%{latest_status: "completed"}, %{latest_status: "cancelled"}]
      assert Helpers.filter_sessions_by_status(sessions, :failed) == []
    end
  end

  describe "filter_tickets_by_status/2" do
    test "returns all tickets when status is :all" do
      tickets = [
        %{task_status: "running", state: "open", sub_tickets: []},
        %{task_status: "completed", state: "closed", sub_tickets: []}
      ]

      assert Helpers.filter_tickets_by_status(tickets, :all) == tickets
    end

    test ":open returns only tickets with state open" do
      tickets = [
        %{task_status: "running", state: "open", sub_tickets: []},
        %{task_status: nil, state: "open", sub_tickets: []},
        %{task_status: "completed", state: "closed", sub_tickets: []}
      ]

      result = Helpers.filter_tickets_by_status(tickets, :open)
      assert length(result) == 2
      assert Enum.all?(result, &(&1.state == "open"))
    end

    test ":closed returns only tickets with state closed" do
      tickets = [
        %{task_status: "running", state: "open", sub_tickets: []},
        %{task_status: "completed", state: "closed", sub_tickets: []},
        %{task_status: nil, state: "closed", sub_tickets: []}
      ]

      result = Helpers.filter_tickets_by_status(tickets, :closed)
      assert length(result) == 2
      assert Enum.all?(result, &(&1.state == "closed"))
    end

    test ":open keeps closed parent visible when it has open sub-tickets" do
      tickets = [
        %{
          task_status: nil,
          state: "closed",
          sub_tickets: [
            %{state: "open", task_status: nil, sub_tickets: []},
            %{state: "closed", task_status: nil, sub_tickets: []}
          ]
        },
        %{task_status: nil, state: "open", sub_tickets: []}
      ]

      result = Helpers.filter_tickets_by_status(tickets, :open)
      assert length(result) == 2

      # The closed parent should be included with only its open sub-tickets
      parent = Enum.find(result, &(&1.state == "closed"))
      assert parent != nil
      assert length(parent.sub_tickets) == 1
      assert hd(parent.sub_tickets).state == "open"
    end

    test ":open excludes closed parent when all sub-tickets are also closed" do
      tickets = [
        %{
          task_status: nil,
          state: "closed",
          sub_tickets: [
            %{state: "closed", task_status: nil, sub_tickets: []}
          ]
        }
      ]

      result = Helpers.filter_tickets_by_status(tickets, :open)
      assert result == []
    end

    test ":open filters sub-tickets to only show open ones" do
      tickets = [
        %{
          task_status: nil,
          state: "open",
          sub_tickets: [
            %{state: "open", task_status: nil, sub_tickets: []},
            %{state: "closed", task_status: nil, sub_tickets: []},
            %{state: "open", task_status: "running", sub_tickets: []}
          ]
        }
      ]

      result = Helpers.filter_tickets_by_status(tickets, :open)
      assert length(result) == 1
      assert length(hd(result).sub_tickets) == 2
      assert Enum.all?(hd(result).sub_tickets, &(&1.state == "open"))
    end

    test ":closed keeps open parent visible when it has closed sub-tickets" do
      tickets = [
        %{
          task_status: nil,
          state: "open",
          sub_tickets: [
            %{state: "closed", task_status: nil, sub_tickets: []},
            %{state: "open", task_status: nil, sub_tickets: []}
          ]
        }
      ]

      result = Helpers.filter_tickets_by_status(tickets, :closed)
      assert length(result) == 1

      parent = hd(result)
      assert parent.state == "open"
      assert length(parent.sub_tickets) == 1
      assert hd(parent.sub_tickets).state == "closed"
    end

    test "filters by exact task_status" do
      tickets = [
        %{task_status: "completed", state: "open"},
        %{task_status: "failed", state: "open"},
        %{task_status: "queued", state: "open"}
      ]

      result = Helpers.filter_tickets_by_status(tickets, :failed)
      assert length(result) == 1
      assert hd(result).task_status == "failed"
    end

    test ":running matches pending, starting, and running" do
      tickets = [
        %{task_status: "pending", state: "open"},
        %{task_status: "starting", state: "open"},
        %{task_status: "running", state: "open"},
        %{task_status: "completed", state: "open"}
      ]

      result = Helpers.filter_tickets_by_status(tickets, :running)
      assert length(result) == 3
    end

    test "returns empty list when no tickets match" do
      tickets = [%{task_status: "completed", state: "open", sub_tickets: []}]
      assert Helpers.filter_tickets_by_status(tickets, :queued) == []
    end

    test ":open surfaces deeply nested open sub-tickets" do
      tickets = [
        %{
          task_status: nil,
          state: "closed",
          sub_tickets: [
            %{
              state: "closed",
              task_status: nil,
              sub_tickets: [
                %{state: "open", task_status: nil, sub_tickets: []}
              ]
            }
          ]
        }
      ]

      result = Helpers.filter_tickets_by_status(tickets, :open)
      assert length(result) == 1

      grandparent = hd(result)
      assert grandparent.state == "closed"

      parent = hd(grandparent.sub_tickets)
      assert parent.state == "closed"

      child = hd(parent.sub_tickets)
      assert child.state == "open"
    end

    test ":closed surfaces deeply nested closed sub-tickets" do
      tickets = [
        %{
          task_status: nil,
          state: "open",
          sub_tickets: [
            %{
              state: "open",
              task_status: nil,
              sub_tickets: [
                %{state: "closed", task_status: nil, sub_tickets: []}
              ]
            }
          ]
        }
      ]

      result = Helpers.filter_tickets_by_status(tickets, :closed)
      assert length(result) == 1

      grandparent = hd(result)
      parent = hd(grandparent.sub_tickets)
      child = hd(parent.sub_tickets)
      assert child.state == "closed"
    end
  end

  describe "last_user_message/1" do
    test "returns the text of the last user message" do
      parts = [
        {:user, "u1", "First message"},
        {:text, "t1", "Response", :frozen},
        {:user, "u2", "Second message"},
        {:text, "t2", "Another response", :frozen}
      ]

      assert Helpers.last_user_message(parts) == "Second message"
    end

    test "returns pending user message text" do
      parts = [
        {:user, "u1", "First message"},
        {:text, "t1", "Response", :frozen},
        {:user_pending, "u2", "Pending follow-up"}
      ]

      assert Helpers.last_user_message(parts) == "Pending follow-up"
    end

    test "returns nil when no user messages exist" do
      parts = [
        {:text, "t1", "Some text", :frozen},
        {:tool, "tool1", "read_file", "completed", nil}
      ]

      assert Helpers.last_user_message(parts) == nil
    end

    test "returns nil for empty list" do
      assert Helpers.last_user_message([]) == nil
    end

    test "returns nil for non-list input" do
      assert Helpers.last_user_message(nil) == nil
    end

    test "returns answer_submitted message text" do
      parts = [
        {:user, "u1", "First message"},
        {:text, "t1", "Response", :frozen},
        {:answer_submitted, "a1", "Re: Deploy — Yes"}
      ]

      assert Helpers.last_user_message(parts) == "Re: Deploy — Yes"
    end
  end

  describe "resumable_task?/1" do
    test "returns true for completed task with container_id and session_id" do
      task = %{status: "completed", container_id: "cid-1", session_id: "sid-1"}
      assert Helpers.resumable_task?(task)
    end

    test "returns true for failed task with container_id and session_id" do
      task = %{status: "failed", container_id: "cid-1", session_id: "sid-1"}
      assert Helpers.resumable_task?(task)
    end

    test "returns true for cancelled task with container_id and session_id" do
      task = %{status: "cancelled", container_id: "cid-1", session_id: "sid-1"}
      assert Helpers.resumable_task?(task)
    end

    test "returns false for terminal task without container_id" do
      task = %{status: "completed", container_id: nil, session_id: "sid-1"}
      refute Helpers.resumable_task?(task)
    end

    test "returns false for terminal task without session_id" do
      task = %{status: "completed", container_id: "cid-1", session_id: nil}
      refute Helpers.resumable_task?(task)
    end

    test "returns false for running task" do
      task = %{status: "running", container_id: "cid-1", session_id: "sid-1"}
      refute Helpers.resumable_task?(task)
    end

    test "returns false for nil" do
      refute Helpers.resumable_task?(nil)
    end
  end
end
