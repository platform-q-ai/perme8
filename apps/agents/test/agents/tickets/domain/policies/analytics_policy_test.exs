defmodule Agents.Tickets.Domain.Policies.AnalyticsPolicyTest do
  use ExUnit.Case, async: true

  alias Agents.Tickets.Domain.Policies.AnalyticsPolicy

  describe "count_by_stage/1" do
    test "counts tickets grouped by lifecycle stage" do
      tickets = [
        %{lifecycle_stage: "open"},
        %{lifecycle_stage: "open"},
        %{lifecycle_stage: "in_progress"},
        %{lifecycle_stage: "closed"}
      ]

      result = AnalyticsPolicy.count_by_stage(tickets)

      assert result["open"] == 2
      assert result["in_progress"] == 1
      assert result["closed"] == 1
      assert result["ready"] == 0
      assert result["in_review"] == 0
      assert result["ci_testing"] == 0
      assert result["deployed"] == 0
    end

    test "returns all stages with zero counts for empty list" do
      result = AnalyticsPolicy.count_by_stage([])

      assert result == %{
               "open" => 0,
               "ready" => 0,
               "in_progress" => 0,
               "in_review" => 0,
               "ci_testing" => 0,
               "deployed" => 0,
               "closed" => 0
             }
    end

    test "ignores unknown stages" do
      tickets = [
        %{lifecycle_stage: "open"},
        %{lifecycle_stage: "unknown_stage"}
      ]

      result = AnalyticsPolicy.count_by_stage(tickets)
      assert result["open"] == 1
      # unknown_stage is silently ignored
      assert Map.keys(result) |> Enum.sort() ==
               ["ci_testing", "closed", "deployed", "in_progress", "in_review", "open", "ready"]
    end
  end

  describe "summarize/3" do
    test "returns summary metrics for tickets and events" do
      tickets = [
        %{id: 1, lifecycle_stage: "open"},
        %{id: 2, lifecycle_stage: "closed"},
        %{id: 3, lifecycle_stage: "in_progress"}
      ]

      events = [
        %{
          ticket_id: 1,
          from_stage: nil,
          to_stage: "open",
          transitioned_at: ~U[2026-03-01 10:00:00Z]
        },
        %{
          ticket_id: 2,
          from_stage: nil,
          to_stage: "open",
          transitioned_at: ~U[2026-03-01 10:00:00Z]
        },
        %{
          ticket_id: 2,
          from_stage: "open",
          to_stage: "closed",
          transitioned_at: ~U[2026-03-05 10:00:00Z]
        }
      ]

      result = AnalyticsPolicy.summarize(tickets, events, {~D[2026-03-01], ~D[2026-03-31]})

      assert result.total == 3
      assert result.open == 2
      assert result.completed == 1
      # avg cycle time for ticket 2: 4 days = 345600 seconds
      assert result.avg_cycle_time_seconds == 345_600
    end

    test "returns nil avg_cycle_time when no tickets are closed" do
      tickets = [%{id: 1, lifecycle_stage: "open"}]

      events = [
        %{
          ticket_id: 1,
          from_stage: nil,
          to_stage: "open",
          transitioned_at: ~U[2026-03-01 10:00:00Z]
        }
      ]

      result = AnalyticsPolicy.summarize(tickets, events, {~D[2026-03-01], ~D[2026-03-31]})

      assert result.avg_cycle_time_seconds == nil
    end

    test "returns zeros for empty data" do
      result = AnalyticsPolicy.summarize([], [], {~D[2026-03-01], ~D[2026-03-31]})

      assert result == %{total: 0, open: 0, avg_cycle_time_seconds: nil, completed: 0}
    end
  end

  describe "completed_in_range/2" do
    test "counts tickets that entered closed stage within range" do
      events = [
        %{ticket_id: 1, to_stage: "closed", transitioned_at: ~U[2026-03-05 10:00:00Z]},
        %{ticket_id: 2, to_stage: "closed", transitioned_at: ~U[2026-03-15 10:00:00Z]},
        %{ticket_id: 3, to_stage: "closed", transitioned_at: ~U[2026-02-15 10:00:00Z]},
        %{ticket_id: 4, to_stage: "in_progress", transitioned_at: ~U[2026-03-10 10:00:00Z]}
      ]

      assert AnalyticsPolicy.completed_in_range(events, {~D[2026-03-01], ~D[2026-03-31]}) == 2
    end

    test "counts each ticket only once even with multiple close events" do
      events = [
        %{ticket_id: 1, to_stage: "closed", transitioned_at: ~U[2026-03-05 10:00:00Z]},
        %{ticket_id: 1, to_stage: "closed", transitioned_at: ~U[2026-03-10 10:00:00Z]}
      ]

      assert AnalyticsPolicy.completed_in_range(events, {~D[2026-03-01], ~D[2026-03-31]}) == 1
    end

    test "returns 0 for empty events" do
      assert AnalyticsPolicy.completed_in_range([], {~D[2026-03-01], ~D[2026-03-31]}) == 0
    end
  end

  describe "bucket_transitions/3" do
    test "groups events into daily buckets" do
      events = [
        %{
          ticket_id: 1,
          to_stage: "in_progress",
          transitioned_at: ~U[2026-03-01 10:00:00Z]
        },
        %{
          ticket_id: 2,
          to_stage: "in_progress",
          transitioned_at: ~U[2026-03-01 14:00:00Z]
        },
        %{
          ticket_id: 3,
          to_stage: "in_review",
          transitioned_at: ~U[2026-03-02 09:00:00Z]
        }
      ]

      result =
        AnalyticsPolicy.bucket_transitions(events, :daily, {~D[2026-03-01], ~D[2026-03-02]})

      in_progress_mar1 =
        Enum.find(result, &(&1.bucket == ~D[2026-03-01] && &1.stage == "in_progress"))

      in_review_mar2 =
        Enum.find(result, &(&1.bucket == ~D[2026-03-02] && &1.stage == "in_review"))

      assert in_progress_mar1.count == 2
      assert in_review_mar2.count == 1
    end

    test "groups events into weekly buckets" do
      # 2026-03-02 is a Monday
      events = [
        %{ticket_id: 1, to_stage: "open", transitioned_at: ~U[2026-03-03 10:00:00Z]},
        %{ticket_id: 2, to_stage: "open", transitioned_at: ~U[2026-03-05 10:00:00Z]}
      ]

      result =
        AnalyticsPolicy.bucket_transitions(events, :weekly, {~D[2026-03-01], ~D[2026-03-08]})

      assert Enum.all?(result, &(&1.bucket == ~D[2026-03-02]))
    end

    test "returns empty list for no events" do
      assert AnalyticsPolicy.bucket_transitions([], :daily, {~D[2026-03-01], ~D[2026-03-31]}) ==
               []
    end
  end

  describe "bucket_cycle_times/3" do
    test "computes average stage durations per bucket" do
      events = [
        %{
          ticket_id: 1,
          to_stage: "open",
          transitioned_at: ~U[2026-03-01 10:00:00Z]
        },
        %{
          ticket_id: 1,
          to_stage: "in_progress",
          transitioned_at: ~U[2026-03-01 12:00:00Z]
        }
      ]

      result =
        AnalyticsPolicy.bucket_cycle_times(events, :daily, {~D[2026-03-01], ~D[2026-03-01]})

      open_entry = Enum.find(result, &(&1.stage == "open"))
      assert open_entry.avg_seconds == 7200.0
      assert open_entry.bucket == ~D[2026-03-01]
    end

    test "returns empty list for no events" do
      assert AnalyticsPolicy.bucket_cycle_times([], :daily, {~D[2026-03-01], ~D[2026-03-31]}) ==
               []
    end
  end

  describe "time_buckets/3" do
    test "generates daily buckets" do
      buckets = AnalyticsPolicy.time_buckets(~D[2026-03-01], ~D[2026-03-03], :daily)
      assert buckets == [~D[2026-03-01], ~D[2026-03-02], ~D[2026-03-03]]
    end

    test "generates weekly buckets" do
      # 2026-03-01 is a Sunday, so bucket_key gives Monday Feb 23
      # Then: Feb 23, Mar 2, Mar 9
      buckets = AnalyticsPolicy.time_buckets(~D[2026-03-01], ~D[2026-03-15], :weekly)
      assert buckets == [~D[2026-02-23], ~D[2026-03-02], ~D[2026-03-09]]
    end

    test "generates monthly buckets" do
      buckets = AnalyticsPolicy.time_buckets(~D[2026-01-15], ~D[2026-03-20], :monthly)
      assert buckets == [~D[2026-01-01], ~D[2026-02-01], ~D[2026-03-01]]
    end

    test "returns single bucket when range is within one period" do
      buckets = AnalyticsPolicy.time_buckets(~D[2026-03-01], ~D[2026-03-01], :daily)
      assert buckets == [~D[2026-03-01]]
    end
  end

  describe "bucket_key/2" do
    test "daily returns the date itself" do
      assert AnalyticsPolicy.bucket_key(~U[2026-03-15 14:30:00Z], :daily) == ~D[2026-03-15]
    end

    test "weekly returns the Monday of that week" do
      # 2026-03-18 is a Wednesday
      assert AnalyticsPolicy.bucket_key(~U[2026-03-18 14:30:00Z], :weekly) == ~D[2026-03-16]
    end

    test "monthly returns the first of that month" do
      assert AnalyticsPolicy.bucket_key(~U[2026-03-18 14:30:00Z], :monthly) == ~D[2026-03-01]
    end
  end
end
