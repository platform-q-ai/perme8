defmodule Agents.Tickets.Infrastructure.Repositories.TicketLifecycleEventRepositoryTest do
  use Agents.DataCase

  alias Agents.Repo
  alias Agents.Tickets.Infrastructure.Repositories.TicketLifecycleEventRepository
  alias Agents.Tickets.Infrastructure.Schemas.ProjectTicketSchema

  defp create_ticket!(number) do
    %ProjectTicketSchema{}
    |> ProjectTicketSchema.changeset(%{
      number: number,
      title: "Ticket #{number}",
      created_at: DateTime.utc_now() |> DateTime.truncate(:second),
      labels: []
    })
    |> Repo.insert!()
  end

  describe "create/1" do
    test "inserts a lifecycle event" do
      ticket = create_ticket!(1401)

      assert {:ok, event} =
               TicketLifecycleEventRepository.create(%{
                 ticket_id: ticket.id,
                 from_stage: nil,
                 to_stage: "open",
                 transitioned_at: ~U[2026-03-11 10:00:00Z],
                 trigger: "sync"
               })

      assert event.ticket_id == ticket.id
      assert event.to_stage == "open"
    end
  end

  describe "list_for_ticket/1" do
    test "returns events ordered by transitioned_at ascending" do
      ticket = create_ticket!(1402)

      {:ok, older} =
        TicketLifecycleEventRepository.create(%{
          ticket_id: ticket.id,
          from_stage: nil,
          to_stage: "open",
          transitioned_at: ~U[2026-03-11 09:00:00Z],
          trigger: "sync"
        })

      {:ok, newer} =
        TicketLifecycleEventRepository.create(%{
          ticket_id: ticket.id,
          from_stage: "open",
          to_stage: "ready",
          transitioned_at: ~U[2026-03-11 10:00:00Z],
          trigger: "manual"
        })

      assert [first, second] = TicketLifecycleEventRepository.list_for_ticket(ticket.id)
      assert first.id == older.id
      assert second.id == newer.id
    end

    test "returns empty list when ticket has no events" do
      ticket = create_ticket!(1403)
      assert TicketLifecycleEventRepository.list_for_ticket(ticket.id) == []
    end
  end

  describe "latest_for_ticket/1" do
    test "returns latest event for ticket" do
      ticket = create_ticket!(1404)

      {:ok, _older} =
        TicketLifecycleEventRepository.create(%{
          ticket_id: ticket.id,
          from_stage: nil,
          to_stage: "open",
          transitioned_at: ~U[2026-03-11 09:00:00Z],
          trigger: "sync"
        })

      {:ok, newest} =
        TicketLifecycleEventRepository.create(%{
          ticket_id: ticket.id,
          from_stage: "open",
          to_stage: "ready",
          transitioned_at: ~U[2026-03-11 11:00:00Z],
          trigger: "manual"
        })

      assert %{id: id} = TicketLifecycleEventRepository.latest_for_ticket(ticket.id)
      assert id == newest.id
    end
  end
end
