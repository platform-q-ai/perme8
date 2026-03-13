defmodule AgentsWeb.DashboardLive.TicketLifecycleFixtures do
  @moduledoc """
  Dev/test fixture data for ticket lifecycle UI previews.

  Provides canned ticket datasets keyed by fixture name so that LiveView
  can be loaded with `?fixture=ticket_lifecycle_*` query params for visual
  testing without requiring real GitHub data.
  """

  import Phoenix.Component, only: [assign: 3]

  alias Agents.Tickets.Domain.Entities.Ticket
  alias Agents.Tickets.Domain.Entities.TicketLifecycleEvent

  def maybe_apply_ticket_lifecycle_fixture(socket, %{"fixture" => fixture})
      when is_binary(fixture) do
    case ticket_lifecycle_fixture_tickets(fixture) do
      [] ->
        assign(socket, :fixture, fixture)

      tickets ->
        active_ticket_number = tickets |> List.first() |> then(&(&1 && &1.number))

        socket
        |> assign(:fixture, fixture)
        |> assign(:sessions, [])
        |> assign(:tasks_snapshot, [])
        |> assign(:tickets, tickets)
        |> assign(:active_ticket_number, active_ticket_number)
    end
  end

  def maybe_apply_ticket_lifecycle_fixture(socket, _params) do
    assign(socket, :fixture, nil)
  end

  def ticket_lifecycle_fixture_tickets("ticket_lifecycle_in_progress") do
    [
      lifecycle_fixture_ticket(402, "Lifecycle in progress",
        external_id: "in-progress-ticket",
        lifecycle_stage: "in_progress",
        lifecycle_stage_entered_at: DateTime.add(DateTime.utc_now(), -1800, :second)
      )
    ]
  end

  def ticket_lifecycle_fixture_tickets("ticket_lifecycle_in_progress_duration") do
    [
      lifecycle_fixture_ticket(402, "Lifecycle in progress duration",
        external_id: "in-progress-duration-ticket",
        lifecycle_stage: "in_progress",
        lifecycle_stage_entered_at: DateTime.add(DateTime.utc_now(), -7200, :second)
      )
    ]
  end

  def ticket_lifecycle_fixture_tickets("ticket_lifecycle_all_stages") do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    [
      {5001, "open"},
      {5002, "ready"},
      {5003, "in_progress"},
      {5004, "in_review"},
      {5005, "ci_testing"},
      {5006, "deployed"},
      {5007, "closed"}
    ]
    |> Enum.with_index()
    |> Enum.map(fn {{number, stage}, idx} ->
      lifecycle_fixture_ticket(number, "Lifecycle stage #{stage}",
        lifecycle_stage: stage,
        lifecycle_stage_entered_at: DateTime.add(now, -3600 * (idx + 1), :second)
      )
    end)
  end

  def ticket_lifecycle_fixture_tickets("ticket_lifecycle_timeline") do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    events = [
      TicketLifecycleEvent.new(%{
        id: 1,
        ticket_id: 430,
        from_stage: nil,
        to_stage: "open",
        transitioned_at: DateTime.add(now, -18_000, :second),
        trigger: "sync"
      }),
      TicketLifecycleEvent.new(%{
        id: 2,
        ticket_id: 430,
        from_stage: "open",
        to_stage: "ready",
        transitioned_at: DateTime.add(now, -12_000, :second),
        trigger: "manual"
      }),
      TicketLifecycleEvent.new(%{
        id: 3,
        ticket_id: 430,
        from_stage: "ready",
        to_stage: "in_progress",
        transitioned_at: DateTime.add(now, -6_000, :second),
        trigger: "manual"
      })
    ]

    [
      lifecycle_fixture_ticket(430, "Timeline fixture",
        external_id: "timeline-ticket",
        lifecycle_stage: "in_progress",
        lifecycle_stage_entered_at: DateTime.add(now, -6_000, :second),
        lifecycle_events: events
      )
    ]
  end

  def ticket_lifecycle_fixture_tickets("ticket_lifecycle_relative_durations") do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    events = [
      TicketLifecycleEvent.new(%{
        id: 11,
        ticket_id: 431,
        from_stage: nil,
        to_stage: "open",
        transitioned_at: DateTime.add(now, -10_000, :second),
        trigger: "sync"
      }),
      TicketLifecycleEvent.new(%{
        id: 12,
        ticket_id: 431,
        from_stage: "open",
        to_stage: "ready",
        transitioned_at: DateTime.add(now, -9_000, :second),
        trigger: "manual"
      }),
      TicketLifecycleEvent.new(%{
        id: 13,
        ticket_id: 431,
        from_stage: "ready",
        to_stage: "in_progress",
        transitioned_at: DateTime.add(now, -6_000, :second),
        trigger: "manual"
      })
    ]

    [
      lifecycle_fixture_ticket(431, "Relative durations fixture",
        external_id: "relative-durations-ticket",
        lifecycle_stage: "in_progress",
        lifecycle_stage_entered_at: DateTime.add(now, -6_000, :second),
        lifecycle_events: events
      )
    ]
  end

  def ticket_lifecycle_fixture_tickets("ticket_lifecycle_realtime_transition") do
    [
      lifecycle_fixture_ticket(402, "Realtime transition ticket",
        lifecycle_stage: "in_progress",
        lifecycle_stage_entered_at: DateTime.add(DateTime.utc_now(), -7200, :second)
      )
    ]
  end

  def ticket_lifecycle_fixture_tickets("ticket_lifecycle_newly_synced") do
    [
      lifecycle_fixture_ticket(450, "Newly synced ticket",
        external_id: "newly-synced-ticket",
        lifecycle_stage: "open",
        lifecycle_stage_entered_at: DateTime.add(DateTime.utc_now(), -300, :second)
      )
    ]
  end

  def ticket_lifecycle_fixture_tickets("ticket_lifecycle_closed") do
    [
      lifecycle_fixture_ticket(451, "Closed ticket fixture",
        external_id: "closed-ticket",
        lifecycle_stage: "closed",
        lifecycle_stage_entered_at: DateTime.add(DateTime.utc_now(), -3600, :second)
      )
    ]
  end

  def ticket_lifecycle_fixture_tickets("ticket_lifecycle_no_events") do
    [
      lifecycle_fixture_ticket(452, "No events ticket fixture",
        external_id: "default-lifecycle-ticket",
        lifecycle_stage: "open",
        lifecycle_stage_entered_at: nil,
        lifecycle_events: []
      )
    ]
  end

  def ticket_lifecycle_fixture_tickets(_fixture), do: []

  def lifecycle_fixture_ticket(number, title, attrs) do
    defaults = %{
      id: number,
      number: number,
      title: title,
      state: "open",
      labels: ["agents"],
      lifecycle_stage: "open",
      lifecycle_stage_entered_at: DateTime.utc_now() |> DateTime.truncate(:second),
      lifecycle_events: [],
      sub_tickets: [],
      position: 0,
      session_state: "idle",
      task_status: nil,
      associated_task_id: nil,
      associated_container_id: nil
    }

    defaults
    |> Map.merge(Map.new(attrs))
    |> Ticket.new()
  end
end
