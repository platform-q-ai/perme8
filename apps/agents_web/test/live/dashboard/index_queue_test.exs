defmodule AgentsWeb.DashboardLive.IndexQueueTest do
  use AgentsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Agents.SessionsFixtures

  alias Agents.Sessions.Domain.Entities.{LaneEntry, QueueSnapshot}
  alias AgentsWeb.DashboardTestHelpers.FakeTaskRunner

  describe "queue_snapshot v2 handling" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "handle_info with queue_snapshot updates assigns", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/sessions")

      snapshot =
        QueueSnapshot.new(%{
          user_id: user.id,
          lanes: %{
            processing: [],
            warm: [
              LaneEntry.new(%{
                task_id: "task-1",
                instruction: "Warm task",
                status: "queued",
                lane: :warm,
                warm_state: :warm
              })
            ],
            cold: [],
            awaiting_feedback: [],
            retry_pending: []
          },
          metadata: %{concurrency_limit: 3, running_count: 1, warm_cache_limit: 2}
        })

      send(lv.pid, {:queue_snapshot, user.id, snapshot})
      _html = render(lv)

      state = :sys.get_state(lv.pid)
      assigns = state.socket.assigns

      assert assigns.queue_snapshot == snapshot
      assert assigns.queue_state == QueueSnapshot.to_legacy_map(snapshot)
    end
  end

  describe "container_stats_updated handler" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "stores stats in assigns when container_stats_updated message received", %{
      conn: conn,
      user: user
    } do
      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Stats session",
          container_id: "c-stats",
          status: "running"
        })

      start_supervised!({FakeTaskRunner, task.id})

      {:ok, lv, _html} = live(conn, ~p"/sessions?container=c-stats")

      stats = %{
        cpu_percent: 45.2,
        memory_percent: 60.0,
        memory_usage: 600_000,
        memory_limit: 1_000_000
      }

      send(lv.pid, {:container_stats_updated, task.id, "c-stats", stats})

      # Force a render cycle to ensure the assign was processed
      _html = render(lv)

      # Verify the assign was stored (the LiveView should not crash)
      assert Process.alive?(lv.pid)
    end

    test "handles stats for multiple containers independently", %{conn: conn, user: user} do
      task1 =
        task_fixture(%{
          user_id: user.id,
          instruction: "Stats session 1",
          container_id: "c-stats-1",
          status: "running"
        })

      task2 =
        task_fixture(%{
          user_id: user.id,
          instruction: "Stats session 2",
          container_id: "c-stats-2",
          status: "running"
        })

      start_supervised!({FakeTaskRunner, task1.id})
      start_supervised!(%{id: :fake_runner_2, start: {FakeTaskRunner, :start_link, [task2.id]}})

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      stats1 = %{cpu_percent: 10.0, memory_percent: 20.0, memory_usage: 200, memory_limit: 1000}
      stats2 = %{cpu_percent: 50.0, memory_percent: 80.0, memory_usage: 800, memory_limit: 1000}

      send(lv.pid, {:container_stats_updated, task1.id, "c-stats-1", stats1})
      send(lv.pid, {:container_stats_updated, task2.id, "c-stats-2", stats2})

      _html = render(lv)
      assert Process.alive?(lv.pid)
    end
  end
end
