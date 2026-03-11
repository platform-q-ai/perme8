defmodule Agents.TicketsTest do
  use Agents.DataCase

  alias Agents.Repo
  alias Agents.Tickets
  alias Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
  alias Agents.Tickets.Infrastructure.Schemas.ProjectTicketSchema

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
end
