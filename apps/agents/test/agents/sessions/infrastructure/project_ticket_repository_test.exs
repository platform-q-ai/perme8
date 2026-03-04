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

  test "sync_remote_ticket/1 does not overwrite pending_push local edits" do
    {:ok, local_ticket} =
      %ProjectTicketSchema{}
      |> ProjectTicketSchema.changeset(%{
        number: 700,
        title: "Local Title",
        status: "In progress",
        priority: "Want",
        labels: ["local"],
        sync_state: "pending_push"
      })
      |> Repo.insert()

    assert {:ok, synced_ticket} =
             ProjectTicketRepository.sync_remote_ticket(%{
               number: 700,
               title: "Remote Title",
               status: "Backlog",
               priority: "Need",
               labels: ["remote"]
             })

    assert synced_ticket.id == local_ticket.id

    refreshed = Repo.get!(ProjectTicketSchema, local_ticket.id)
    assert refreshed.title == "Local Title"
    assert refreshed.status == "In progress"
    assert refreshed.priority == "Want"
    assert refreshed.labels == ["local"]
    assert refreshed.sync_state == "pending_push"
  end

  test "sync_remote_ticket/1 does not overwrite sync_error local edits" do
    {:ok, local_ticket} =
      %ProjectTicketSchema{}
      |> ProjectTicketSchema.changeset(%{
        number: 701,
        title: "Local Error Title",
        status: "In review",
        priority: "Nice to have",
        labels: ["local-error"],
        sync_state: "sync_error",
        last_sync_error: "push failed"
      })
      |> Repo.insert()

    assert {:ok, synced_ticket} =
             ProjectTicketRepository.sync_remote_ticket(%{
               number: 701,
               title: "Remote Title",
               status: "Backlog",
               priority: "Need",
               labels: ["remote"]
             })

    assert synced_ticket.id == local_ticket.id

    refreshed = Repo.get!(ProjectTicketSchema, local_ticket.id)
    assert refreshed.title == "Local Error Title"
    assert refreshed.status == "In review"
    assert refreshed.priority == "Nice to have"
    assert refreshed.labels == ["local-error"]
    assert refreshed.sync_state == "sync_error"
    assert refreshed.last_sync_error == "push failed"
  end

  test "sync_remote_ticket/1 persists the body field from remote data" do
    body_text = "## Description\nThis is the ticket body with **markdown**."

    assert {:ok, ticket} =
             ProjectTicketRepository.sync_remote_ticket(%{
               number: 800,
               title: "Ticket with body",
               body: body_text,
               status: "Backlog",
               labels: []
             })

    assert ticket.body == body_text

    refreshed = Repo.get!(ProjectTicketSchema, ticket.id)
    assert refreshed.body == body_text
  end

  test "sync_remote_ticket/1 handles nil body gracefully" do
    assert {:ok, ticket} =
             ProjectTicketRepository.sync_remote_ticket(%{
               number: 801,
               title: "Ticket without body",
               status: "Backlog",
               labels: []
             })

    assert ticket.body == nil
  end

  test "changeset accepts body field" do
    changeset =
      ProjectTicketSchema.changeset(%ProjectTicketSchema{}, %{
        number: 900,
        title: "Schema body test",
        body: "Some body content"
      })

    assert changeset.valid?
    assert Ecto.Changeset.get_change(changeset, :body) == "Some body content"
  end
end
