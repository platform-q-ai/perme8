defmodule Agents.TicketsTest do
  use Agents.DataCase

  alias Agents.Repo
  alias Agents.Tickets
  alias Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
  alias Agents.Tickets.Infrastructure.Schemas.ProjectTicketSchema
  alias Perme8.Events.TestEventBus

  setup do
    TestEventBus.start_global()
    :ok
  end

  defp create_ticket!(number, attrs \\ %{}) do
    base = %{
      number: number,
      title: "Ticket #{number}",
      created_at: ~U[2026-03-11 09:00:00Z],
      labels: []
    }

    %ProjectTicketSchema{}
    |> ProjectTicketSchema.changeset(Map.merge(base, attrs))
    |> Repo.insert!()
  end

  describe "record_ticket_stage_transition/3" do
    test "records transition and returns updated ticket and lifecycle event" do
      ticket = create_ticket!(402)
      now = ~U[2026-03-11 12:00:00Z]

      assert {:ok, %{ticket: updated_ticket, lifecycle_event: lifecycle_event}} =
               Tickets.record_ticket_stage_transition(ticket.id, "ready",
                 trigger: "manual",
                 now: now
               )

      assert updated_ticket.lifecycle_stage == "ready"
      assert lifecycle_event.ticket_id == ticket.id
      assert lifecycle_event.from_stage == "open"
      assert lifecycle_event.to_stage == "ready"
      assert lifecycle_event.trigger == "manual"
    end
  end

  describe "get_ticket_lifecycle/1" do
    test "returns ticket with preloaded lifecycle events" do
      ticket = create_ticket!(403)

      assert {:ok, _} =
               Tickets.record_ticket_stage_transition(ticket.id, "in_progress",
                 trigger: "sync",
                 now: ~U[2026-03-11 13:00:00Z]
               )

      assert {:ok, lifecycle_ticket} = Tickets.get_ticket_lifecycle(ticket.id)
      assert lifecycle_ticket.id == ticket.id
      assert lifecycle_ticket.lifecycle_stage == "in_progress"
      assert length(lifecycle_ticket.lifecycle_events) == 1
      assert hd(lifecycle_ticket.lifecycle_events).to_stage == "in_progress"
    end
  end

  describe "list_project_tickets/2" do
    test "returns lifecycle fields on mapped ticket entities" do
      create_ticket!(404, %{
        lifecycle_stage: "closed",
        lifecycle_stage_entered_at: ~U[2026-03-11 14:00:00Z],
        state: "closed"
      })

      [ticket] =
        Tickets.list_project_tickets("user-id",
          tasks: [],
          tickets: ProjectTicketRepository.list_all()
        )

      assert ticket.lifecycle_stage == "closed"
      assert ticket.lifecycle_stage_entered_at == ~U[2026-03-11 14:00:00Z]
      assert ticket.lifecycle_events == []
    end
  end

  describe "close_project_ticket/2" do
    @close_opts [actor_id: "user-close", event_bus: TestEventBus]

    test "closes ticket locally with pending_push sync state" do
      create_ticket!(700, %{state: "open"})

      assert :ok = Tickets.close_project_ticket(700, @close_opts)

      refreshed = Repo.get_by!(ProjectTicketSchema, number: 700)
      assert refreshed.state == "closed"
      assert refreshed.sync_state == "pending_push"
    end

    test "emits TicketClosed domain event" do
      create_ticket!(701, %{state: "open"})

      assert :ok = Tickets.close_project_ticket(701, @close_opts)

      events = TestEventBus.get_events()
      assert [%Agents.Tickets.Domain.Events.TicketClosed{} = event] = events
      assert event.number == 701
      assert event.actor_id == "user-close"
    end

    test "returns error when ticket does not exist locally" do
      assert {:error, :not_found} = Tickets.close_project_ticket(9999, @close_opts)
    end
  end

  describe "update_ticket_labels/3" do
    @actor_id "user-labels-test"

    setup do
      TestEventBus.start_global()
      :ok
    end

    test "updates labels locally with sync_state pending_push" do
      create_ticket!(750, %{labels: ["old-label"]})

      assert {:ok, schema} =
               Tickets.update_ticket_labels(750, ["bug", "agents"],
                 actor_id: @actor_id,
                 event_bus: TestEventBus
               )

      assert schema.labels == ["bug", "agents"]
      assert schema.sync_state == "pending_push"

      refreshed = Repo.get_by!(ProjectTicketSchema, number: 750)
      assert refreshed.labels == ["bug", "agents"]
      assert refreshed.sync_state == "pending_push"
    end

    test "emits TicketUpdated event with label changes" do
      create_ticket!(751, %{labels: ["old"]})

      assert {:ok, _} =
               Tickets.update_ticket_labels(751, ["new"],
                 actor_id: @actor_id,
                 event_bus: TestEventBus
               )

      events = TestEventBus.get_events()
      assert [%{event_type: "tickets.ticket_updated"} = event] = events
      assert event.number == 751
      assert event.changes == %{labels: ["new"]}
      assert event.actor_id == @actor_id
    end

    test "returns error when ticket does not exist" do
      assert {:error, :not_found} =
               Tickets.update_ticket_labels(99_999, ["bug"],
                 actor_id: @actor_id,
                 event_bus: TestEventBus
               )
    end

    test "can set labels to empty list" do
      create_ticket!(753, %{labels: ["bug", "frontend"]})

      assert {:ok, schema} =
               Tickets.update_ticket_labels(753, [],
                 actor_id: @actor_id,
                 event_bus: TestEventBus
               )

      assert schema.labels == []
      assert schema.sync_state == "pending_push"

      refreshed = Repo.get_by!(ProjectTicketSchema, number: 753)
      assert refreshed.labels == []
    end
  end
end
