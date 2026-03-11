defmodule AgentsWeb.DashboardLive.LifecycleTimelineTest do
  use AgentsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  test "renders lifecycle timeline in ticket detail tab", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sessions?fixture=ticket_lifecycle_timeline")

    view
    |> element("[data-testid='triage-ticket-item']")
    |> render_click()

    view
    |> element("button[data-tab-id='ticket']")
    |> render_click()

    assert has_element?(view, "[data-testid='ticket-lifecycle-timeline']")

    html = render(view)

    assert length(Regex.scan(~r/data-testid="ticket-lifecycle-timeline-stage"/, html)) == 3

    assert has_element?(
             view,
             "[data-testid='ticket-lifecycle-timeline-stage-duration']"
           )
  end

  test "shows relative duration bars with stage attributes", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sessions?fixture=ticket_lifecycle_relative_durations")

    view
    |> element("[data-testid='triage-ticket-item']")
    |> render_click()

    view
    |> element("button[data-tab-id='ticket']")
    |> render_click()

    assert has_element?(view, "[data-testid='ticket-lifecycle-timeline']")

    assert has_element?(
             view,
             "[data-testid='ticket-lifecycle-duration-bar'][data-stage='open'][data-relative-width='10']"
           )

    assert has_element?(
             view,
             "[data-testid='ticket-lifecycle-duration-bar'][data-stage='ready'][data-relative-width='30']"
           )

    assert has_element?(
             view,
             "[data-testid='ticket-lifecycle-duration-bar'][data-stage='in_progress'][data-relative-width='60']"
           )
  end
end
