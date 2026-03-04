defmodule Agents.Sessions.Infrastructure.ProjectTicketRepositoryTest do
  use Agents.DataCase, async: true

  alias Agents.Repo
  alias Agents.Sessions.Infrastructure.Repositories.ProjectTicketRepository
  alias Agents.Sessions.Infrastructure.Schemas.ProjectTicketSchema

  test "sync_remote_ticket/1 persists remote tickets with sync metadata" do
    assert {:ok, ticket} =
             ProjectTicketRepository.sync_remote_ticket(%{
               number: 306,
               title: "Ticket 306",
               status: "Backlog",
               priority: "Need",
               labels: ["agents"]
             })

    assert ticket.number == 306
    assert ticket.sync_state == "synced"
    assert ticket.last_synced_at
    assert ticket.last_sync_error == nil
  end

  test "mark_sync_error/2 marks pending local updates with error details" do
    {:ok, ticket} =
      %ProjectTicketSchema{}
      |> ProjectTicketSchema.changeset(%{
        number: 500,
        title: "Ticket 500",
        status: "Backlog",
        labels: [],
        sync_state: "pending_push"
      })
      |> Repo.insert()

    assert {:ok, _} = ProjectTicketRepository.mark_sync_error(ticket, :boom)

    refreshed = Repo.get!(ProjectTicketSchema, ticket.id)
    assert refreshed.sync_state == "sync_error"
    assert refreshed.last_sync_error =~ "boom"
  end
end
