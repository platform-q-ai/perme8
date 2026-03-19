defmodule Agents.Tickets.Domain.Entities.AnalyticsViewTest do
  use ExUnit.Case, async: true

  alias Agents.Tickets.Domain.Entities.AnalyticsView

  describe "distribution_bars/2" do
    test "returns bar data for each stage with correct heights" do
      stage_counts = %{
        "open" => 10,
        "ready" => 5,
        "in_progress" => 3,
        "in_review" => 0,
        "ci_testing" => 0,
        "deployed" => 0,
        "closed" => 8
      }

      bars = AnalyticsView.distribution_bars(stage_counts, 200.0)

      assert length(bars) == 7

      open_bar = Enum.find(bars, &(&1.stage == "open"))
      assert open_bar.count == 10
      assert open_bar.bar_height == 200.0
      assert open_bar.y_offset == 0.0
      assert open_bar.label == "Open"
      assert open_bar.color == "neutral"

      ready_bar = Enum.find(bars, &(&1.stage == "ready"))
      assert ready_bar.count == 5
      assert ready_bar.bar_height == 100.0

      review_bar = Enum.find(bars, &(&1.stage == "in_review"))
      assert review_bar.count == 0
      assert review_bar.bar_height == 0.0
    end

    test "handles empty counts gracefully" do
      stage_counts = %{
        "open" => 0,
        "ready" => 0,
        "in_progress" => 0,
        "in_review" => 0,
        "ci_testing" => 0,
        "deployed" => 0,
        "closed" => 0
      }

      bars = AnalyticsView.distribution_bars(stage_counts, 200.0)

      assert Enum.all?(bars, &(&1.bar_height == 0.0))
    end
  end

  describe "trend_line_points/4" do
    test "returns polyline point strings per stage" do
      buckets = [~D[2026-03-01], ~D[2026-03-02], ~D[2026-03-03]]

      data = [
        %{bucket: ~D[2026-03-01], stage: "open", count: 5},
        %{bucket: ~D[2026-03-02], stage: "open", count: 10},
        %{bucket: ~D[2026-03-03], stage: "open", count: 3}
      ]

      result = AnalyticsView.trend_line_points(data, {600, 200}, buckets)

      assert Map.has_key?(result, "open")
      assert is_binary(result["open"])
      # Should have 3 points separated by spaces
      points = String.split(result["open"], " ")
      assert length(points) == 3
    end

    test "returns empty map for empty buckets" do
      assert AnalyticsView.trend_line_points([], {600, 200}, []) == %{}
    end

    test "handles single bucket" do
      data = [%{bucket: ~D[2026-03-01], stage: "open", count: 5}]
      result = AnalyticsView.trend_line_points(data, {600, 200}, [~D[2026-03-01]])

      assert Map.has_key?(result, "open")
    end
  end

  describe "chart_x_labels/2" do
    test "formats daily labels as month/day" do
      buckets = [~D[2026-03-01], ~D[2026-03-15]]
      labels = AnalyticsView.chart_x_labels(buckets, :daily)

      assert labels == ["3/1", "3/15"]
    end

    test "formats weekly labels with W prefix" do
      buckets = [~D[2026-03-02], ~D[2026-03-09]]
      labels = AnalyticsView.chart_x_labels(buckets, :weekly)

      assert labels == ["W3/2", "W3/9"]
    end

    test "formats monthly labels as month names" do
      buckets = [~D[2026-01-01], ~D[2026-02-01], ~D[2026-03-01]]
      labels = AnalyticsView.chart_x_labels(buckets, :monthly)

      assert labels == ["Jan", "Feb", "Mar"]
    end

    test "returns empty list for no buckets" do
      assert AnalyticsView.chart_x_labels([], :daily) == []
    end
  end

  describe "summary_display/1" do
    test "formats summary for display" do
      summary = %{total: 42, open: 15, avg_cycle_time_seconds: 172_800, completed: 7}

      display = AnalyticsView.summary_display(summary)

      assert display.total == "42"
      assert display.open == "15"
      assert display.avg_cycle_time == "2d"
      assert display.completed == "7"
    end

    test "shows N/A for nil cycle time" do
      summary = %{total: 0, open: 0, avg_cycle_time_seconds: nil, completed: 0}

      display = AnalyticsView.summary_display(summary)
      assert display.avg_cycle_time == "N/A"
    end

    test "formats hours and minutes correctly" do
      summary = %{total: 1, open: 1, avg_cycle_time_seconds: 5400, completed: 0}

      display = AnalyticsView.summary_display(summary)
      assert display.avg_cycle_time == "1h 30m"
    end
  end
end
