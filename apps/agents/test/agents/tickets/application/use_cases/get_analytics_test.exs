defmodule Agents.Tickets.Application.UseCases.GetAnalyticsTest do
  use ExUnit.Case, async: true

  alias Agents.Tickets.Application.UseCases.GetAnalytics

  defmodule StubAnalyticsRepo do
    @moduledoc false

    def get_analytics_data(_opts) do
      %{
        tickets: [
          %{id: 1, lifecycle_stage: "open"},
          %{id: 2, lifecycle_stage: "in_progress"},
          %{id: 3, lifecycle_stage: "closed"}
        ],
        events: [
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
            transitioned_at: ~U[2026-03-02 10:00:00Z]
          },
          %{
            ticket_id: 2,
            from_stage: "open",
            to_stage: "in_progress",
            transitioned_at: ~U[2026-03-03 10:00:00Z]
          },
          %{
            ticket_id: 3,
            from_stage: nil,
            to_stage: "open",
            transitioned_at: ~U[2026-03-01 08:00:00Z]
          },
          %{
            ticket_id: 3,
            from_stage: "open",
            to_stage: "closed",
            transitioned_at: ~U[2026-03-05 08:00:00Z]
          }
        ]
      }
    end
  end

  defmodule EmptyAnalyticsRepo do
    @moduledoc false

    def get_analytics_data(_opts) do
      %{tickets: [], events: []}
    end
  end

  describe "execute/1" do
    test "returns analytics with default options" do
      {:ok, analytics} =
        GetAnalytics.execute(
          analytics_repo: StubAnalyticsRepo,
          date_from: ~D[2026-03-01],
          date_to: ~D[2026-03-31]
        )

      assert analytics.summary.total == 3
      assert analytics.summary.open == 2
      assert analytics.summary.completed == 1
      assert analytics.granularity == :daily
      assert analytics.date_from == ~D[2026-03-01]
      assert analytics.date_to == ~D[2026-03-31]

      # Distribution should have all stages
      assert Map.has_key?(analytics.distribution, "open")
      assert Map.has_key?(analytics.distribution, "closed")

      # Buckets should be generated
      assert length(analytics.buckets) > 0
    end

    test "respects custom granularity" do
      {:ok, analytics} =
        GetAnalytics.execute(
          analytics_repo: StubAnalyticsRepo,
          granularity: :weekly,
          date_from: ~D[2026-03-01],
          date_to: ~D[2026-03-31]
        )

      assert analytics.granularity == :weekly
    end

    test "returns empty analytics for no data" do
      {:ok, analytics} =
        GetAnalytics.execute(
          analytics_repo: EmptyAnalyticsRepo,
          date_from: ~D[2026-03-01],
          date_to: ~D[2026-03-31]
        )

      assert analytics.summary.total == 0
      assert analytics.summary.open == 0
      assert analytics.summary.completed == 0
      assert analytics.summary.avg_cycle_time_seconds == nil
      assert analytics.throughput == []
      assert analytics.cycle_times == []
    end

    test "uses default date range when not specified" do
      {:ok, analytics} = GetAnalytics.execute(analytics_repo: EmptyAnalyticsRepo)

      assert analytics.date_to == Date.utc_today()
      assert analytics.date_from == Date.add(Date.utc_today(), -30)
    end
  end
end
