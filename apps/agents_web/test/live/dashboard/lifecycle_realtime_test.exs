defmodule AgentsWeb.DashboardLive.LifecycleRealtimeTest do
  use AgentsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  test "handle_info updates lifecycle stage and resets duration", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sessions?fixture=ticket_lifecycle_realtime_transition")

    assert has_element?(
             view,
             "[data-ticket-id='ticket-402'] [data-testid='ticket-lifecycle-stage']",
             "In Progress"
           )

    transitioned_at = DateTime.utc_now() |> DateTime.truncate(:second)
    send(view.pid, {:ticket_stage_changed, 402, "in_review", transitioned_at})

    assert has_element?(
             view,
             "[data-ticket-id='ticket-402'] [data-testid='ticket-lifecycle-stage']",
             "In Review"
           )

    assert has_element?(
             view,
             "[data-ticket-id='ticket-402'] [data-testid='ticket-lifecycle-duration']",
             "0m"
           )
  end

  test "multiple tickets receive independent lifecycle updates", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sessions?fixture=ticket_lifecycle_all_stages")

    transitioned_at = DateTime.utc_now() |> DateTime.truncate(:second)
    send(view.pid, {:ticket_stage_changed, 5001, "closed", transitioned_at})

    assert has_element?(
             view,
             "[data-ticket-id='ticket-5001'] [data-testid='ticket-lifecycle-stage']",
             "Closed"
           )

    assert has_element?(
             view,
             "[data-ticket-id='ticket-5002'] [data-testid='ticket-lifecycle-stage']",
             "Ready"
           )
  end
end
