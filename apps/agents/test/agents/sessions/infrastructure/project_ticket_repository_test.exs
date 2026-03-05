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

  test "reorder_positions/1 persists ticket positions in order" do
    for {number, title} <- [{10, "Ticket 10"}, {20, "Ticket 20"}, {30, "Ticket 30"}] do
      %ProjectTicketSchema{}
      |> ProjectTicketSchema.changeset(%{
        number: number,
        title: title,
        status: "Backlog",
        labels: []
      })
      |> Repo.insert!()
    end

    assert :ok = ProjectTicketRepository.reorder_positions([30, 10, 20])

    tickets = ProjectTicketRepository.list_by_statuses(["Backlog"])
    numbers = Enum.map(tickets, & &1.number)

    assert numbers == [30, 10, 20]
  end

  test "reorder_positions/1 preserves positions across remote sync" do
    for {number, title} <- [{40, "Ticket 40"}, {50, "Ticket 50"}] do
      %ProjectTicketSchema{}
      |> ProjectTicketSchema.changeset(%{
        number: number,
        title: title,
        status: "Ready",
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
        status: "Ready",
        labels: []
      })

    tickets = ProjectTicketRepository.list_by_statuses(["Ready"])
    numbers = Enum.map(tickets, & &1.number)

    assert numbers == [50, 40]
  end

  test "new tickets from remote sync are appended after existing tickets" do
    # Create two existing tickets with known positions
    %ProjectTicketSchema{}
    |> ProjectTicketSchema.changeset(%{
      number: 990,
      title: "Existing ticket 1",
      status: "Backlog",
      position: 0,
      labels: []
    })
    |> Repo.insert!()

    %ProjectTicketSchema{}
    |> ProjectTicketSchema.changeset(%{
      number: 991,
      title: "Existing ticket 2",
      status: "Backlog",
      position: 1,
      labels: []
    })
    |> Repo.insert!()

    # Sync a brand new ticket — should get position 2 (max + 1)
    {:ok, ticket} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 999,
        title: "Brand new ticket",
        status: "Backlog",
        labels: []
      })

    assert ticket.position == 2
  end

  test "first new ticket from remote sync gets position 0" do
    {:ok, ticket} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 998,
        title: "Very first ticket",
        status: "Backlog",
        labels: []
      })

    assert ticket.position == 0
  end

  test "new tickets from remote sync do not disrupt existing ordering" do
    # Set up 3 tickets with explicit positions
    for {number, position} <- [{200, 0}, {201, 1}, {202, 2}] do
      %ProjectTicketSchema{}
      |> ProjectTicketSchema.changeset(%{
        number: number,
        title: "Ticket #{number}",
        status: "Backlog",
        position: position,
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
        status: "Backlog",
        labels: []
      })

    # New ticket should be appended at position 3
    assert new_ticket.position == 3

    # Full ordering should preserve user's drag order with new ticket at end
    tickets = ProjectTicketRepository.list_by_statuses(["Backlog"])
    numbers = Enum.map(tickets, & &1.number)
    assert numbers == [202, 200, 201, 203]
  end

  test "list_by_statuses/1 orders by priority when positions are equal" do
    for {number, priority} <- [
          {60, "Nice to have"},
          {61, "Need"},
          {62, "Want"},
          {63, nil}
        ] do
      %ProjectTicketSchema{}
      |> ProjectTicketSchema.changeset(%{
        number: number,
        title: "Ticket #{number}",
        status: "Backlog",
        priority: priority,
        labels: []
      })
      |> Repo.insert!()
    end

    tickets = ProjectTicketRepository.list_by_statuses(["Backlog"])
    numbers = Enum.map(tickets, & &1.number)

    # Need (61) > Want (62) > Nice to have (60) > nil (63)
    assert numbers == [61, 62, 60, 63]
  end

  test "list_by_statuses/1 orders by size when position and priority are equal" do
    for {number, size} <- [
          {70, "XS"},
          {71, "XL"},
          {72, "M"},
          {73, "L"},
          {74, "S"},
          {75, nil}
        ] do
      %ProjectTicketSchema{}
      |> ProjectTicketSchema.changeset(%{
        number: number,
        title: "Ticket #{number}",
        status: "Backlog",
        priority: "Need",
        size: size,
        labels: []
      })
      |> Repo.insert!()
    end

    tickets = ProjectTicketRepository.list_by_statuses(["Backlog"])
    numbers = Enum.map(tickets, & &1.number)

    # XL (71) > L (73) > M (72) > S (74) > XS (70) > nil (75)
    assert numbers == [71, 73, 72, 74, 70, 75]
  end

  test "list_by_statuses/1 orders by inserted_at desc when position, priority, and size are equal" do
    # Insert two tickets with same position, priority, size but different timestamps
    {:ok, older} =
      %ProjectTicketSchema{}
      |> ProjectTicketSchema.changeset(%{
        number: 80,
        title: "Older ticket",
        status: "Backlog",
        priority: "Need",
        size: "M",
        labels: []
      })
      |> Repo.insert()

    # Ensure a different inserted_at by updating the older one's timestamp
    Repo.query!("UPDATE sessions_project_tickets SET inserted_at = $1 WHERE id = $2", [
      ~U[2025-01-01 00:00:00Z],
      older.id
    ])

    {:ok, _newer} =
      %ProjectTicketSchema{}
      |> ProjectTicketSchema.changeset(%{
        number: 81,
        title: "Newer ticket",
        status: "Backlog",
        priority: "Need",
        size: "M",
        labels: []
      })
      |> Repo.insert()

    tickets = ProjectTicketRepository.list_by_statuses(["Backlog"])
    numbers = Enum.map(tickets, & &1.number)

    # Newer (81) before older (80) because inserted_at DESC
    assert numbers == [81, 80]
  end

  test "list_by_statuses/1 full ordering cascade: position > priority > size > inserted_at" do
    # Position 0, Need, XL — should be first
    %ProjectTicketSchema{}
    |> ProjectTicketSchema.changeset(%{
      number: 90,
      title: "Pos0 Need XL",
      status: "Backlog",
      priority: "Need",
      size: "XL",
      position: 0,
      labels: []
    })
    |> Repo.insert!()

    # Position 0, Need, S — same position/priority, smaller size
    %ProjectTicketSchema{}
    |> ProjectTicketSchema.changeset(%{
      number: 91,
      title: "Pos0 Need S",
      status: "Backlog",
      priority: "Need",
      size: "S",
      position: 0,
      labels: []
    })
    |> Repo.insert!()

    # Position 0, Nice to have, XL — same position, lower priority
    %ProjectTicketSchema{}
    |> ProjectTicketSchema.changeset(%{
      number: 92,
      title: "Pos0 NiceToHave XL",
      status: "Backlog",
      priority: "Nice to have",
      size: "XL",
      position: 0,
      labels: []
    })
    |> Repo.insert!()

    # Position 1, Need, XL — higher position number, so comes after position 0
    %ProjectTicketSchema{}
    |> ProjectTicketSchema.changeset(%{
      number: 93,
      title: "Pos1 Need XL",
      status: "Backlog",
      priority: "Need",
      size: "XL",
      position: 1,
      labels: []
    })
    |> Repo.insert!()

    tickets = ProjectTicketRepository.list_by_statuses(["Backlog"])
    numbers = Enum.map(tickets, & &1.number)

    # Position 0 group: Need/XL (90), Need/S (91), NiceToHave/XL (92)
    # Position 1 group: Need/XL (93)
    assert numbers == [90, 91, 92, 93]
  end

  test "delete_by_number/1 removes an existing ticket" do
    %ProjectTicketSchema{}
    |> ProjectTicketSchema.changeset(%{
      number: 100,
      title: "Ticket to delete",
      status: "Backlog",
      labels: []
    })
    |> Repo.insert!()

    assert {:ok, deleted} = ProjectTicketRepository.delete_by_number(100)
    assert deleted.number == 100

    assert ProjectTicketRepository.list_by_statuses(["Backlog"]) == []
  end

  test "delete_by_number/1 returns error for non-existent ticket" do
    assert {:error, :not_found} = ProjectTicketRepository.delete_by_number(99999)
  end
end
