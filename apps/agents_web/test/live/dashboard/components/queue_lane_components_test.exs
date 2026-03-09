defmodule AgentsWeb.DashboardLive.Components.QueueLaneComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Agents.Sessions.Domain.Entities.{LaneEntry, QueueSnapshot}
  alias AgentsWeb.DashboardLive.Components.QueueLaneComponents

  describe "queue_lanes/1" do
    test "renders processing lane at bottom via flex-col-reverse" do
      snapshot =
        QueueSnapshot.new(%{
          lanes: %{
            processing: [entry("processing-1", :processing)],
            warm: [entry("warm-1", :warm)]
          }
        })

      html = render_component(&QueueLaneComponents.queue_lanes/1, snapshot: snapshot)

      assert html =~ ~s(data-testid="queue-lanes")
      assert html =~ "flex-col-reverse"
      assert String.contains?(html, ~s(data-testid="lane-processing"))
      assert String.contains?(html, ~s(data-testid="lane-warm"))
    end

    test "renders correct number of entries per lane" do
      snapshot =
        QueueSnapshot.new(%{
          lanes: %{
            processing: [entry("p-1", :processing), entry("p-2", :processing)],
            warm: [entry("w-1", :warm)]
          }
        })

      html = render_component(&QueueLaneComponents.queue_lanes/1, snapshot: snapshot)

      assert html =~ "Processing"
      assert html =~ "(2)"
      assert html =~ "Warm"
      assert html =~ "(1)"
      assert length(:binary.matches(html, ~s(data-testid="task-card"))) == 3
    end

    test "empty lanes are not rendered" do
      snapshot =
        QueueSnapshot.new(%{
          lanes: %{
            processing: [entry("p-1", :processing)]
          }
        })

      html = render_component(&QueueLaneComponents.queue_lanes/1, snapshot: snapshot)

      assert html =~ ~s(data-testid="lane-processing")
      refute html =~ ~s(data-testid="lane-warm")
      refute html =~ ~s(data-testid="lane-cold")
      refute html =~ ~s(data-testid="lane-awaiting_feedback")
      refute html =~ ~s(data-testid="lane-retry_pending")
    end
  end

  describe "lane_entry/1" do
    test "shows running, warm, warming, and cold indicators" do
      running_html =
        render_component(&QueueLaneComponents.lane_entry/1,
          entry: entry("running-1", :processing),
          lane: :processing
        )

      warm_html =
        render_component(&QueueLaneComponents.lane_entry/1,
          entry: entry("warm-1", :warm),
          lane: :warm
        )

      cold_html =
        render_component(&QueueLaneComponents.lane_entry/1,
          entry: entry("cold-1", :cold, warm_state: :cold),
          lane: :cold
        )

      warming_html =
        render_component(&QueueLaneComponents.lane_entry/1,
          entry: entry("warming-1", :warm, warm_state: :warming),
          lane: :warm
        )

      assert running_html =~ ~s(data-testid="warm-state-indicator-hot")
      assert warm_html =~ ~s(data-testid="warm-state-indicator-warm")
      assert warming_html =~ ~s(data-testid="warm-state-indicator-warming")
      assert cold_html =~ ~s(data-testid="warm-state-indicator-cold")
    end

    test "shows retry badge when retry_count is greater than zero" do
      html =
        render_component(&QueueLaneComponents.lane_entry/1,
          entry: entry("retry-1", :retry_pending, retry_count: 2),
          lane: :retry_pending
        )

      assert html =~ "2/3"
      assert html =~ "badge-error"
    end
  end

  describe "queue_metadata/1" do
    test "shows running count and concurrency limit" do
      snapshot =
        QueueSnapshot.new(%{
          metadata: %{concurrency_limit: 4, running_count: 2, warm_cache_limit: 2}
        })

      html = render_component(&QueueLaneComponents.queue_metadata/1, snapshot: snapshot)

      assert html =~ "2/4 running"
    end

    test "shows available slots" do
      snapshot =
        QueueSnapshot.new(%{
          metadata: %{concurrency_limit: 3, running_count: 1, warm_cache_limit: 2}
        })

      html = render_component(&QueueLaneComponents.queue_metadata/1, snapshot: snapshot)

      assert html =~ "2 slots available"
    end
  end

  defp entry(task_id, lane, overrides \\ []) do
    defaults = [
      task_id: task_id,
      instruction: "Instruction #{task_id}",
      status: "queued",
      lane: lane,
      warm_state: lane_warm_state(lane),
      retry_count: 0
    ]

    LaneEntry.new(Enum.into(Keyword.merge(defaults, overrides), %{}))
  end

  defp lane_warm_state(:warm), do: :warm
  defp lane_warm_state(:processing), do: :hot
  defp lane_warm_state(_), do: :cold
end
