defmodule AgentsWeb.DashboardLive.PipelineKanbanTest do
  use AgentsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Agents.Pipeline.Domain.Events.PipelineStageChanged

  setup :register_and_log_in_user

  test "renders bottom pipeline kanban and removes build column", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/sessions?fixture=pipeline_kanban_layout_enabled")

    assert html =~ ~s(data-testid="pipeline-kanban")
    assert has_element?(view, "#triage-lane")
    refute html =~ "Builds"
    assert has_element?(view, "[data-testid='kanban-column-in_progress']")
  end

  test "collapses kanban to status bar and selects ticket sessions", %{conn: conn} do
    {:ok, view, _html} =
      live(conn, ~p"/sessions?fixture=pipeline_kanban_ticket_to_session_selection")

    view
    |> element("[data-testid='toggle-pipeline-kanban']")
    |> render_click()

    assert has_element?(view, "[data-testid='kanban-status-bar']")

    view
    |> element("[data-testid='toggle-pipeline-kanban']")
    |> render_click()

    view
    |> element("[data-testid='kanban-ticket-card-402']")
    |> render_click()

    assert_patch(view, "/sessions?ticket=402&container=c-pipeline-402&tab=ticket")
  end

  test "moves kanban tickets when pipeline stage events arrive", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sessions?fixture=pipeline_kanban_live_stage_change")

    assert has_element?(
             view,
             "[data-testid='kanban-column-ready'] [data-testid='kanban-ticket-card-425']"
           )

    send(
      view.pid,
      PipelineStageChanged.new(%{
        aggregate_id: Ecto.UUID.generate(),
        actor_id: "pipeline",
        pipeline_run_id: Ecto.UUID.generate(),
        stage_id: "test",
        from_status: "running_stage",
        to_status: "awaiting_result",
        task_id: "task-425"
      })
    )

    assert has_element?(
             view,
             "[data-testid='kanban-column-ci_testing'] [data-testid='kanban-ticket-card-425']"
           )

    refute has_element?(
             view,
             "[data-testid='kanban-column-ready'] [data-testid='kanban-ticket-card-425']"
           )
  end
end
