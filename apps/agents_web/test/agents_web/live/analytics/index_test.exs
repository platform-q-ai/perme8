defmodule AgentsWeb.AnalyticsLive.IndexTest do
  use AgentsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Agents.Tickets.Infrastructure.Schemas.ProjectTicketSchema
  alias Agents.Tickets.Infrastructure.Schemas.TicketLifecycleEventSchema

  setup :register_and_log_in_user

  describe "mount" do
    test "renders analytics page for authenticated user", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/analytics")

      assert html =~ "Analytics"
      assert has_element?(view, "[data-testid='summary-card-total-tickets']")
      assert has_element?(view, "[data-testid='summary-card-open-tickets']")
      assert has_element?(view, "[data-testid='summary-card-avg-cycle-time']")
      assert has_element?(view, "[data-testid='summary-card-completed']")
    end

    test "redirects unauthenticated user to login" do
      conn = build_conn()
      assert {:error, {:redirect, %{to: _login_path}}} = live(conn, ~p"/analytics")
    end
  end

  describe "with lifecycle data" do
    setup do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      ticket1 =
        Agents.Repo.insert!(%ProjectTicketSchema{
          number: 1001,
          title: "Test ticket 1",
          state: "open",
          lifecycle_stage: "in_progress",
          sync_state: "synced",
          created_at: DateTime.add(now, -14, :day)
        })

      ticket2 =
        Agents.Repo.insert!(%ProjectTicketSchema{
          number: 1002,
          title: "Test ticket 2",
          state: "closed",
          lifecycle_stage: "closed",
          sync_state: "synced",
          created_at: DateTime.add(now, -14, :day)
        })

      Agents.Repo.insert!(%TicketLifecycleEventSchema{
        ticket_id: ticket1.id,
        from_stage: nil,
        to_stage: "open",
        transitioned_at: DateTime.add(now, -7, :day),
        trigger: "system"
      })

      Agents.Repo.insert!(%TicketLifecycleEventSchema{
        ticket_id: ticket1.id,
        from_stage: "open",
        to_stage: "in_progress",
        transitioned_at: DateTime.add(now, -5, :day),
        trigger: "system"
      })

      Agents.Repo.insert!(%TicketLifecycleEventSchema{
        ticket_id: ticket2.id,
        from_stage: nil,
        to_stage: "open",
        transitioned_at: DateTime.add(now, -10, :day),
        trigger: "system"
      })

      Agents.Repo.insert!(%TicketLifecycleEventSchema{
        ticket_id: ticket2.id,
        from_stage: "open",
        to_stage: "closed",
        transitioned_at: DateTime.add(now, -3, :day),
        trigger: "system"
      })

      {:ok, ticket1: ticket1, ticket2: ticket2, now: now}
    end

    test "displays distribution chart with data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/analytics")

      assert has_element?(view, "[data-testid='stage-distribution-chart']")
      assert has_element?(view, "[data-testid='stage-bar-open']")
      assert has_element?(view, "[data-testid='stage-bar-in_progress']")
      assert has_element?(view, "[data-testid='stage-bar-closed']")
    end

    test "displays trend charts with data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/analytics")

      assert has_element?(view, "[data-testid='throughput-trend-chart']")
      assert has_element?(view, "[data-testid='cycle-time-trend-chart']")
    end
  end

  describe "granularity toggle" do
    test "renders granularity toggle", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/analytics")

      assert has_element?(view, "[data-testid='granularity-toggle']")
      assert has_element?(view, "button", "Daily")
      assert has_element?(view, "button", "Weekly")
      assert has_element?(view, "button", "Monthly")
    end

    test "clicking Weekly updates granularity", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/analytics")

      view |> element("button", "Weekly") |> render_click()

      assert has_element?(
               view,
               "[data-testid='granularity-toggle'] button[aria-pressed='true']",
               "Weekly"
             )
    end

    test "clicking Monthly updates granularity", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/analytics")

      view |> element("button", "Monthly") |> render_click()

      assert has_element?(
               view,
               "[data-testid='granularity-toggle'] button[aria-pressed='true']",
               "Monthly"
             )
    end
  end

  describe "date range filter" do
    test "renders date range filter", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/analytics")

      assert has_element?(view, "[data-testid='date-range-filter']")
      assert has_element?(view, "[data-testid='date-range-start']")
      assert has_element?(view, "[data-testid='date-range-end']")
    end

    test "changing start date triggers filter update", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/analytics")

      view
      |> element("[data-testid='date-range-start']")
      |> render_change(%{"date_from" => "2026-01-01"})

      # Should not crash and should still render analytics
      assert render(view) =~ "Analytics"
    end

    test "changing end date triggers filter update", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/analytics")

      view
      |> element("[data-testid='date-range-end']")
      |> render_change(%{"date_to" => "2026-03-31"})

      assert render(view) =~ "Analytics"
    end

    test "rejects invalid date range where start is after end", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/analytics")

      view
      |> element("[data-testid='date-range-start']")
      |> render_change(%{"date_from" => "2026-12-31"})

      assert render(view) =~ "Start date must be before end date"
    end

    test "rejects invalid date format", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/analytics")

      view
      |> element("[data-testid='date-range-start']")
      |> render_change(%{"date_from" => "not-a-date"})

      assert render(view) =~ "Invalid date format"
    end
  end

  describe "empty state" do
    test "shows empty state when no lifecycle data exists", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/analytics")

      assert html =~ "No lifecycle data yet"
    end
  end

  describe "real-time updates" do
    test "schedules debounced refresh on TicketStageChanged event", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/analytics")

      event = %Agents.Tickets.Domain.Events.TicketStageChanged{
        event_id: Ecto.UUID.generate(),
        event_type: "tickets.ticket_stage_changed",
        aggregate_type: "ticket",
        aggregate_id: "1",
        actor_id: "system",
        occurred_at: DateTime.utc_now(),
        metadata: %{},
        ticket_id: 1,
        from_stage: "open",
        to_stage: "in_progress",
        trigger: "system"
      }

      send(view.pid, event)

      # After the debounce timer fires, the view should re-render without crashing
      send(view.pid, :do_refresh)
      assert render(view) =~ "Analytics"
    end
  end

  describe "sidebar navigation" do
    test "analytics link is visible in sidebar", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sessions")

      assert html =~ ~s(href="/analytics")
      assert html =~ "Analytics"
    end
  end
end
