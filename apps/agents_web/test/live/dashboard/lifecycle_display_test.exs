defmodule AgentsWeb.DashboardLive.LifecycleDisplayTest do
  use AgentsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  test "ticket card renders lifecycle stage and duration", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sessions?fixture=ticket_lifecycle_in_progress")

    assert has_element?(view, "[data-testid='triage-ticket-item']")

    assert has_element?(
             view,
             "[data-testid='triage-ticket-item'] [data-testid='ticket-lifecycle-stage']",
             "In Progress"
           )

    assert has_element?(
             view,
             "[data-testid='triage-ticket-item'] [data-testid='ticket-lifecycle-duration']"
           )
  end

  test "ticket card includes lifecycle and ticket id attributes", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sessions?fixture=ticket_lifecycle_in_progress")

    assert has_element?(
             view,
             "[data-testid='triage-ticket-item'][data-lifecycle-stage='in_progress'][data-ticket-id='ticket-402']"
           )
  end

  test "duration fixture shows two-hour duration", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sessions?fixture=ticket_lifecycle_in_progress_duration")

    assert has_element?(
             view,
             "[data-testid='triage-ticket-item'] [data-testid='ticket-lifecycle-duration']",
             "2h"
           )
  end

  test "renders correct labels for all lifecycle stages", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sessions?fixture=ticket_lifecycle_all_stages")

    assert has_element?(
             view,
             "[data-lifecycle-stage='open'] [data-testid='ticket-lifecycle-stage']",
             "Open"
           )

    assert has_element?(
             view,
             "[data-lifecycle-stage='ready'] [data-testid='ticket-lifecycle-stage']",
             "Ready"
           )

    assert has_element?(
             view,
             "[data-lifecycle-stage='in_progress'] [data-testid='ticket-lifecycle-stage']",
             "In Progress"
           )

    assert has_element?(
             view,
             "[data-lifecycle-stage='in_review'] [data-testid='ticket-lifecycle-stage']",
             "In Review"
           )

    assert has_element?(
             view,
             "[data-lifecycle-stage='ci_testing'] [data-testid='ticket-lifecycle-stage']",
             "CI Testing"
           )

    assert has_element?(
             view,
             "[data-lifecycle-stage='deployed'] [data-testid='ticket-lifecycle-stage']",
             "Deployed"
           )

    assert has_element?(
             view,
             "[data-lifecycle-stage='closed'] [data-testid='ticket-lifecycle-stage']",
             "Closed"
           )
  end

  test "ticket with no lifecycle events falls back to open and 0m", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sessions?fixture=ticket_lifecycle_no_events")

    assert has_element?(
             view,
             "[data-testid='triage-ticket-item'][data-ticket-id='default-lifecycle-ticket'] [data-testid='ticket-lifecycle-stage']",
             "Open"
           )

    assert has_element?(
             view,
             "[data-testid='triage-ticket-item'][data-ticket-id='default-lifecycle-ticket'] [data-testid='ticket-lifecycle-duration']",
             "0m"
           )
  end
end
