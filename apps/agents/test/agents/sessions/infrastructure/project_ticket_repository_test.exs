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
               labels: ["agents"]
             })

    assert ticket.number == 306
    assert ticket.sync_state == "synced"
    assert ticket.last_synced_at
    assert ticket.last_sync_error == nil
  end

  test "sync_remote_ticket/1 overwrites existing ticket data on re-sync" do
    {:ok, _} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 700,
        title: "Original Title",
        labels: ["old"]
      })

    {:ok, synced} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 700,
        title: "Updated Title",
        labels: ["new"]
      })

    refreshed = Repo.get!(ProjectTicketSchema, synced.id)
    assert refreshed.title == "Updated Title"
    assert refreshed.labels == ["new"]
    assert refreshed.sync_state == "synced"
  end

  test "sync_remote_ticket/1 persists the body field from remote data" do
    body_text = "## Description\nThis is the ticket body with **markdown**."

    assert {:ok, ticket} =
             ProjectTicketRepository.sync_remote_ticket(%{
               number: 800,
               title: "Ticket with body",
               body: body_text,
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

  test "reorder_positions/1 persists ticket positions in order" do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    for {number, title} <- [{10, "Ticket 10"}, {20, "Ticket 20"}, {30, "Ticket 30"}] do
      %ProjectTicketSchema{}
      |> ProjectTicketSchema.changeset(%{
        number: number,
        title: title,
        status: "Backlog",
        created_at: now,
        labels: []
      })
      |> Repo.insert!()
    end

    assert :ok = ProjectTicketRepository.reorder_positions([30, 10, 20])

    tickets = ProjectTicketRepository.list_all()
    numbers = Enum.map(tickets, & &1.number)

    assert numbers == [30, 10, 20]
  end

  test "reorder_positions/1 preserves positions across remote sync" do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    for {number, title} <- [{40, "Ticket 40"}, {50, "Ticket 50"}] do
      %ProjectTicketSchema{}
      |> ProjectTicketSchema.changeset(%{
        number: number,
        title: title,
        status: "Ready",
        created_at: now,
        labels: []
      })
      |> Repo.insert!()
    end

    # Set custom order: 50 before 40
    ProjectTicketRepository.reorder_positions([50, 40])

    # Simulate a remote sync — position should be preserved
    {:ok, _} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 40,
        title: "Updated Ticket 40",
        labels: []
      })

    tickets = ProjectTicketRepository.list_all()
    numbers = Enum.map(tickets, & &1.number)

    assert numbers == [50, 40]
  end

  test "new tickets from remote sync are appended after existing tickets" do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Create two existing tickets with known positions
    %ProjectTicketSchema{}
    |> ProjectTicketSchema.changeset(%{
      number: 990,
      title: "Existing ticket 1",
      status: "Backlog",
      position: 0,
      created_at: now,
      labels: []
    })
    |> Repo.insert!()

    %ProjectTicketSchema{}
    |> ProjectTicketSchema.changeset(%{
      number: 991,
      title: "Existing ticket 2",
      status: "Backlog",
      position: 1,
      created_at: now,
      labels: []
    })
    |> Repo.insert!()

    # Sync a brand new ticket — should get position 2 (max + 1)
    {:ok, ticket} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 999,
        title: "Brand new ticket",
        labels: []
      })

    assert ticket.position == 2
  end

  test "first new ticket from remote sync gets position 0" do
    {:ok, ticket} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 998,
        title: "Very first ticket",
        labels: []
      })

    assert ticket.position == 0
  end

  test "new tickets from remote sync do not disrupt existing ordering" do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Set up 3 tickets with explicit positions
    for {number, position} <- [{200, 0}, {201, 1}, {202, 2}] do
      %ProjectTicketSchema{}
      |> ProjectTicketSchema.changeset(%{
        number: number,
        title: "Ticket #{number}",
        status: "Backlog",
        position: position,
        created_at: now,
        labels: []
      })
      |> Repo.insert!()
    end

    # User reorders: 202 first, then 200, then 201
    ProjectTicketRepository.reorder_positions([202, 200, 201])

    # Now sync a new ticket from GitHub
    {:ok, new_ticket} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 203,
        title: "New from GitHub",
        labels: []
      })

    # New ticket should get position max+1 = 3 (highest, so first in desc order)
    assert new_ticket.position == 3

    # list_all orders by position DESC — new ticket (pos 3) appears first,
    # then the user's drag order is preserved: 202(2), 200(1), 201(0)
    tickets = ProjectTicketRepository.list_all()
    numbers = Enum.map(tickets, & &1.number)
    assert numbers == [203, 202, 200, 201]
  end

  test "list_all/0 orders by position then created_at desc" do
    # Insert two tickets with same position but different created_at timestamps
    {:ok, _older} =
      %ProjectTicketSchema{}
      |> ProjectTicketSchema.changeset(%{
        number: 80,
        title: "Older ticket",
        status: "Backlog",
        created_at: ~U[2025-01-01 00:00:00Z],
        labels: []
      })
      |> Repo.insert()

    {:ok, _newer} =
      %ProjectTicketSchema{}
      |> ProjectTicketSchema.changeset(%{
        number: 81,
        title: "Newer ticket",
        status: "Backlog",
        created_at: ~U[2026-03-01 00:00:00Z],
        labels: []
      })
      |> Repo.insert()

    tickets = ProjectTicketRepository.list_all()
    numbers = Enum.map(tickets, & &1.number)

    # Newer (81) before older (80) because created_at DESC
    assert numbers == [81, 80]
  end

  test "delete_by_number/1 removes an existing ticket" do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %ProjectTicketSchema{}
    |> ProjectTicketSchema.changeset(%{
      number: 100,
      title: "Ticket to delete",
      status: "Backlog",
      created_at: now,
      labels: []
    })
    |> Repo.insert!()

    assert {:ok, deleted} = ProjectTicketRepository.delete_by_number(100)
    assert deleted.number == 100

    assert ProjectTicketRepository.list_all() == []
  end

  test "delete_by_number/1 returns error for non-existent ticket" do
    assert {:error, :not_found} = ProjectTicketRepository.delete_by_number(99_999)
  end

  test "delete_not_in/1 removes tickets not in the given set" do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    for number <- [301, 302, 303] do
      %ProjectTicketSchema{}
      |> ProjectTicketSchema.changeset(%{
        number: number,
        title: "Ticket #{number}",
        status: "Backlog",
        created_at: now,
        labels: []
      })
      |> Repo.insert!()
    end

    # Keep only 301 and 303
    {deleted_count, _} = ProjectTicketRepository.delete_not_in(MapSet.new([301, 303]))

    assert deleted_count == 1

    remaining = ProjectTicketRepository.list_all()
    numbers = Enum.map(remaining, & &1.number) |> Enum.sort()
    assert numbers == [301, 303]
  end

  test "delete_not_in/1 with empty set deletes all tickets" do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    for number <- [401, 402] do
      %ProjectTicketSchema{}
      |> ProjectTicketSchema.changeset(%{
        number: number,
        title: "Ticket #{number}",
        status: "Backlog",
        created_at: now,
        labels: []
      })
      |> Repo.insert!()
    end

    {deleted_count, _} = ProjectTicketRepository.delete_not_in(MapSet.new())
    assert deleted_count == 2
    assert ProjectTicketRepository.list_all() == []
  end
end
