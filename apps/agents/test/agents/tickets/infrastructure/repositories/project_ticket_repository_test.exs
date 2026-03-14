defmodule Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepositoryTest do
  use Agents.DataCase, async: true

  alias Agents.Repo
  alias Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
  alias Agents.Tickets.Infrastructure.Schemas.ProjectTicketSchema
  alias Agents.Tickets.Infrastructure.Schemas.TicketLifecycleEventSchema
  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema

  import Agents.Test.AccountsFixtures

  defp create_task!(attrs \\ %{}) do
    user = user_fixture()

    %TaskSchema{}
    |> TaskSchema.changeset(
      Map.merge(%{instruction: "test instruction", user_id: user.id}, attrs)
    )
    |> Repo.insert!()
  end

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

    # Simulate a remote sync - position should be preserved
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

    # Sync a brand new ticket - should get position 2 (max + 1)
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

    # list_all orders by position DESC - new ticket (pos 3) appears first,
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

  test "close_by_number/1 marks an existing ticket as closed" do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %ProjectTicketSchema{}
    |> ProjectTicketSchema.changeset(%{
      number: 500,
      title: "Ticket to close",
      status: "Backlog",
      created_at: now,
      labels: []
    })
    |> Repo.insert!()

    assert {:ok, closed} = ProjectTicketRepository.close_by_number(500)
    assert closed.state == "closed"

    refreshed = Repo.get_by!(ProjectTicketSchema, number: 500)
    assert refreshed.state == "closed"
  end

  test "close_by_number/1 returns error for non-existent ticket" do
    assert {:error, :not_found} = ProjectTicketRepository.close_by_number(99_998)
  end

  test "sync_remote_ticket/1 persists the state field from remote data" do
    assert {:ok, ticket} =
             ProjectTicketRepository.sync_remote_ticket(%{
               number: 600,
               title: "Open ticket",
               state: "open",
               labels: []
             })

    assert ticket.state == "open"

    assert {:ok, closed_ticket} =
             ProjectTicketRepository.sync_remote_ticket(%{
               number: 601,
               title: "Closed ticket",
               state: "closed",
               labels: []
             })

    assert closed_ticket.state == "closed"
  end

  test "sync_remote_ticket/1 updates state on re-sync" do
    {:ok, _} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 602,
        title: "Ticket 602",
        state: "open",
        labels: []
      })

    {:ok, updated} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 602,
        title: "Ticket 602",
        state: "closed",
        labels: []
      })

    assert updated.state == "closed"
  end

  test "new tickets default to open state" do
    assert {:ok, ticket} =
             ProjectTicketRepository.sync_remote_ticket(%{
               number: 603,
               title: "Ticket without state",
               labels: []
             })

    assert ticket.state == "open"
  end

  test "list_all/0 returns only root tickets with sub_tickets preloaded" do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    parent =
      %ProjectTicketSchema{}
      |> ProjectTicketSchema.changeset(%{
        number: 710,
        title: "Parent",
        created_at: now,
        labels: [],
        position: 10
      })
      |> Repo.insert!()

    child =
      %ProjectTicketSchema{}
      |> ProjectTicketSchema.changeset(%{
        number: 711,
        title: "Child",
        created_at: now,
        labels: [],
        position: 3,
        parent_ticket_id: parent.id
      })
      |> Repo.insert!()

    root =
      %ProjectTicketSchema{}
      |> ProjectTicketSchema.changeset(%{
        number: 712,
        title: "Independent",
        created_at: now,
        labels: [],
        position: 5
      })
      |> Repo.insert!()

    [first, second] = ProjectTicketRepository.list_all()

    assert Enum.map([first, second], & &1.number) == [710, 712]
    assert first.sub_tickets != %Ecto.Association.NotLoaded{}
    assert Enum.map(first.sub_tickets, & &1.number) == [child.number]
    assert second.sub_tickets == []

    refute Enum.any?([first, second], &(&1.number == child.number))
    assert Enum.all?([first, second], &is_nil(&1.parent_ticket_id))
    assert root.number == 712
  end

  test "list_all_flat/0 returns all tickets without hierarchy filtering" do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    parent =
      %ProjectTicketSchema{}
      |> ProjectTicketSchema.changeset(%{
        number: 720,
        title: "Parent",
        created_at: now,
        labels: [],
        position: 4
      })
      |> Repo.insert!()

    %ProjectTicketSchema{}
    |> ProjectTicketSchema.changeset(%{
      number: 721,
      title: "Child",
      created_at: now,
      labels: [],
      position: 3,
      parent_ticket_id: parent.id
    })
    |> Repo.insert!()

    %ProjectTicketSchema{}
    |> ProjectTicketSchema.changeset(%{
      number: 722,
      title: "Root",
      created_at: now,
      labels: [],
      position: 2
    })
    |> Repo.insert!()

    numbers = ProjectTicketRepository.list_all_flat() |> Enum.map(& &1.number)
    assert numbers == [720, 721, 722]
  end

  test "sync_remote_ticket/1 persists parent_ticket_id" do
    assert {:ok, parent} =
             ProjectTicketRepository.sync_remote_ticket(%{
               number: 730,
               title: "Parent",
               labels: []
             })

    assert {:ok, child} =
             ProjectTicketRepository.sync_remote_ticket(%{
               number: 731,
               title: "Child",
               labels: [],
               parent_ticket_id: parent.id
             })

    assert child.parent_ticket_id == parent.id

    persisted = Repo.get_by!(ProjectTicketSchema, number: 731)
    assert persisted.parent_ticket_id == parent.id
  end

  test "sync_remote_ticket/1 updates parent_ticket_id on re-sync" do
    {:ok, parent_one} =
      ProjectTicketRepository.sync_remote_ticket(%{number: 740, title: "Parent one", labels: []})

    {:ok, parent_two} =
      ProjectTicketRepository.sync_remote_ticket(%{number: 741, title: "Parent two", labels: []})

    {:ok, _child} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 742,
        title: "Child",
        labels: [],
        parent_ticket_id: parent_one.id
      })

    {:ok, updated} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 742,
        title: "Child",
        labels: [],
        parent_ticket_id: parent_two.id
      })

    assert updated.parent_ticket_id == parent_two.id
    refute updated.parent_ticket_id == parent_one.id
  end

  test "sync_remote_ticket/1 clears parent_ticket_id when promoted to top-level" do
    {:ok, parent} =
      ProjectTicketRepository.sync_remote_ticket(%{number: 750, title: "Parent", labels: []})

    {:ok, _child} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 751,
        title: "Child",
        labels: [],
        parent_ticket_id: parent.id
      })

    {:ok, promoted} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 751,
        title: "Child",
        labels: [],
        parent_ticket_id: nil
      })

    assert promoted.parent_ticket_id == nil
  end

  test "link_sub_tickets/1 resolves parent numbers and updates children" do
    {:ok, _parent} =
      ProjectTicketRepository.sync_remote_ticket(%{number: 760, title: "Parent", labels: []})

    {:ok, child} =
      ProjectTicketRepository.sync_remote_ticket(%{number: 761, title: "Child", labels: []})

    assert :ok = ProjectTicketRepository.link_sub_tickets(%{761 => 760})

    refreshed = Repo.get!(ProjectTicketSchema, child.id)
    parent = Repo.get_by!(ProjectTicketSchema, number: 760)
    assert refreshed.parent_ticket_id == parent.id
  end

  test "link_sub_tickets/1 skips entries where parent does not exist" do
    {:ok, child} =
      ProjectTicketRepository.sync_remote_ticket(%{number: 771, title: "Child", labels: []})

    assert :ok = ProjectTicketRepository.link_sub_tickets(%{771 => 779})

    refreshed = Repo.get!(ProjectTicketSchema, child.id)
    assert refreshed.parent_ticket_id == nil
  end

  describe "link_task/2" do
    test "persists task_id on a ticket" do
      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 850,
          title: "Ticket for linking",
          labels: []
        })

      task = create_task!()
      assert {:ok, linked} = ProjectTicketRepository.link_task(850, task.id)
      assert linked.task_id == task.id

      refreshed = Repo.get_by!(ProjectTicketSchema, number: 850)
      assert refreshed.task_id == task.id
    end

    test "returns error when ticket does not exist" do
      task = create_task!()
      assert {:error, :ticket_not_found} = ProjectTicketRepository.link_task(99_997, task.id)
    end

    test "overwrites previous task_id" do
      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 851,
          title: "Ticket for re-linking",
          labels: []
        })

      old_task = create_task!(%{instruction: "old task"})
      new_task = create_task!(%{instruction: "new task"})

      {:ok, _} = ProjectTicketRepository.link_task(851, old_task.id)
      {:ok, relinked} = ProjectTicketRepository.link_task(851, new_task.id)

      assert relinked.task_id == new_task.id
    end
  end

  describe "unlink_task/1" do
    test "clears task_id on a ticket" do
      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 860,
          title: "Ticket for unlinking",
          labels: []
        })

      task = create_task!()
      {:ok, _} = ProjectTicketRepository.link_task(860, task.id)
      {:ok, unlinked} = ProjectTicketRepository.unlink_task(860)

      assert unlinked.task_id == nil

      refreshed = Repo.get_by!(ProjectTicketSchema, number: 860)
      assert refreshed.task_id == nil
    end

    test "returns error when ticket does not exist" do
      assert {:error, :ticket_not_found} = ProjectTicketRepository.unlink_task(99_996)
    end
  end

  describe "sync_remote_ticket/1 preserves task_id" do
    test "does not clear task_id when re-syncing from remote" do
      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 870,
          title: "Original title",
          labels: []
        })

      task = create_task!()
      {:ok, _} = ProjectTicketRepository.link_task(870, task.id)

      # Simulate a remote sync that updates the title
      {:ok, synced} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 870,
          title: "Updated title",
          labels: ["new-label"]
        })

      assert synced.title == "Updated title"
      assert synced.task_id == task.id
    end
  end

  describe "lifecycle repository integration" do
    test "list_all/0 preloads lifecycle_events ordered by transitioned_at" do
      ticket =
        %ProjectTicketSchema{}
        |> ProjectTicketSchema.changeset(%{
          number: 9001,
          title: "Lifecycle order",
          created_at: ~U[2026-03-11 09:00:00Z],
          labels: []
        })
        |> Repo.insert!()

      %TicketLifecycleEventSchema{}
      |> TicketLifecycleEventSchema.changeset(%{
        ticket_id: ticket.id,
        from_stage: "open",
        to_stage: "ready",
        transitioned_at: ~U[2026-03-11 11:00:00Z],
        trigger: "manual"
      })
      |> Repo.insert!()

      %TicketLifecycleEventSchema{}
      |> TicketLifecycleEventSchema.changeset(%{
        ticket_id: ticket.id,
        from_stage: nil,
        to_stage: "open",
        transitioned_at: ~U[2026-03-11 10:00:00Z],
        trigger: "sync"
      })
      |> Repo.insert!()

      [loaded_ticket] = ProjectTicketRepository.list_all()

      assert loaded_ticket.lifecycle_events != %Ecto.Association.NotLoaded{}
      assert Enum.map(loaded_ticket.lifecycle_events, & &1.to_stage) == ["open", "ready"]
    end

    test "get_by_id/1 returns ticket with lifecycle_events preloaded" do
      ticket =
        %ProjectTicketSchema{}
        |> ProjectTicketSchema.changeset(%{
          number: 9002,
          title: "Lifecycle ticket",
          created_at: ~U[2026-03-11 09:00:00Z],
          labels: []
        })
        |> Repo.insert!()

      %TicketLifecycleEventSchema{}
      |> TicketLifecycleEventSchema.changeset(%{
        ticket_id: ticket.id,
        from_stage: nil,
        to_stage: "open",
        transitioned_at: ~U[2026-03-11 10:00:00Z],
        trigger: "sync"
      })
      |> Repo.insert!()

      assert {:ok, loaded_ticket} = ProjectTicketRepository.get_by_id(ticket.id)
      assert loaded_ticket.id == ticket.id
      assert loaded_ticket.lifecycle_events != %Ecto.Association.NotLoaded{}
      assert length(loaded_ticket.lifecycle_events) == 1

      assert ProjectTicketRepository.get_by_id(-1) == nil
    end

    test "update_lifecycle_stage/3 updates stage and entered_at atomically" do
      ticket =
        %ProjectTicketSchema{}
        |> ProjectTicketSchema.changeset(%{
          number: 9003,
          title: "Lifecycle update",
          created_at: ~U[2026-03-11 09:00:00Z],
          labels: []
        })
        |> Repo.insert!()

      entered_at = ~U[2026-03-11 12:00:00Z]

      assert {:ok, updated} =
               ProjectTicketRepository.update_lifecycle_stage(
                 ticket.id,
                 "in_progress",
                 entered_at
               )

      assert updated.lifecycle_stage == "in_progress"
      assert updated.lifecycle_stage_entered_at == entered_at

      reloaded = Repo.get!(ProjectTicketSchema, ticket.id)
      assert reloaded.lifecycle_stage == "in_progress"
      assert reloaded.lifecycle_stage_entered_at == entered_at
    end
  end

  describe "insert_local/1" do
    test "inserts a new ticket with the given attributes" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      assert {:ok, ticket} =
               ProjectTicketRepository.insert_local(%{
                 number: -1,
                 title: "Local ticket",
                 body: "Created locally",
                 state: "open",
                 sync_state: "pending_push",
                 position: 0,
                 created_at: now
               })

      assert ticket.number == -1
      assert ticket.title == "Local ticket"
      assert ticket.body == "Created locally"
      assert ticket.sync_state == "pending_push"

      persisted = Repo.get!(ProjectTicketSchema, ticket.id)
      assert persisted.title == "Local ticket"
    end

    test "rejects insert without required fields" do
      assert {:error, changeset} =
               ProjectTicketRepository.insert_local(%{
                 title: "Missing number"
               })

      assert errors_on(changeset)[:number]
    end

    test "rejects duplicate number" do
      attrs = %{
        number: -999,
        title: "First",
        state: "open",
        sync_state: "pending_push",
        position: 0,
        created_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      assert {:ok, _} = ProjectTicketRepository.insert_local(attrs)
      assert {:error, changeset} = ProjectTicketRepository.insert_local(attrs)
      assert errors_on(changeset)[:number]
    end
  end

  describe "next_position/0" do
    test "returns 0 when no tickets exist" do
      assert ProjectTicketRepository.next_position() == 0
    end

    test "returns max + 1 when tickets exist" do
      ProjectTicketRepository.sync_remote_ticket(%{number: 900, title: "Pos 0", labels: []})
      ProjectTicketRepository.sync_remote_ticket(%{number: 901, title: "Pos 1", labels: []})

      pos = ProjectTicketRepository.next_position()
      assert pos >= 2
    end
  end

  describe "delete_not_in/1 with pending_push tickets" do
    test "does not prune pending_push tickets" do
      # Create a synced ticket and a pending_push ticket
      {:ok, synced} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 950,
          title: "Synced from GH",
          labels: []
        })

      {:ok, pending} =
        ProjectTicketRepository.insert_local(%{
          number: -42,
          title: "Local pending",
          state: "open",
          sync_state: "pending_push",
          position: 0,
          created_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      # Prune everything not in {950} — pending_push ticket should survive
      ProjectTicketRepository.delete_not_in(MapSet.new([950]))

      assert Repo.get(ProjectTicketSchema, synced.id) != nil
      assert Repo.get(ProjectTicketSchema, pending.id) != nil
    end

    test "prunes synced tickets not in the remote set" do
      {:ok, keeper} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 960,
          title: "Keeper",
          labels: []
        })

      {:ok, pruned} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 961,
          title: "To be pruned",
          labels: []
        })

      ProjectTicketRepository.delete_not_in(MapSet.new([960]))

      assert Repo.get(ProjectTicketSchema, keeper.id) != nil
      assert Repo.get(ProjectTicketSchema, pruned.id) == nil
    end
  end

  describe "FK cascade on task deletion" do
    test "deleting a task row nullifies the ticket's task_id via on_delete cascade" do
      task = create_task!(%{status: "failed", error: "boom"})

      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 950,
          title: "Ticket linked to a task",
          status: "Backlog",
          priority: "Need",
          size: "M",
          labels: []
        })

      # Link the ticket to the task
      {:ok, linked} = ProjectTicketRepository.link_task(950, task.id)
      assert linked.task_id == task.id

      # Delete the task row (simulates what delete_session does)
      Repo.delete!(task)

      # The FK cascade (on_delete: :nilify_all) should clear task_id
      reloaded = Repo.get_by!(ProjectTicketSchema, number: 950)
      assert reloaded.task_id == nil
    end

    test "new link_task after task deletion sets the new task_id" do
      old_task = create_task!(%{status: "failed", error: "boom"})

      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 951,
          title: "Ticket for re-link test",
          status: "Backlog",
          priority: "Need",
          size: "M",
          labels: []
        })

      # Link to old task, then delete it (cascade clears task_id)
      {:ok, _} = ProjectTicketRepository.link_task(951, old_task.id)
      Repo.delete!(old_task)

      reloaded = Repo.get_by!(ProjectTicketSchema, number: 951)
      assert reloaded.task_id == nil

      # Create a new task and link the ticket to it
      new_task = create_task!(%{instruction: "pick up ticket #951"})
      {:ok, re_linked} = ProjectTicketRepository.link_task(951, new_task.id)

      assert re_linked.task_id == new_task.id
    end
  end

  describe "update_labels/2" do
    test "updates labels on an existing ticket" do
      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 960,
          title: "Ticket for label update",
          labels: ["bug"]
        })

      assert {:ok, updated} = ProjectTicketRepository.update_labels(960, ["bug", "agents"])
      assert updated.labels == ["bug", "agents"]

      # Verify persisted in DB
      reloaded = Repo.get_by!(ProjectTicketSchema, number: 960)
      assert reloaded.labels == ["bug", "agents"]
    end

    test "replaces existing labels with new list" do
      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 961,
          title: "Ticket for label replace",
          labels: ["old-label", "another"]
        })

      assert {:ok, updated} = ProjectTicketRepository.update_labels(961, ["new-label"])
      assert updated.labels == ["new-label"]
    end

    test "can set labels to empty list" do
      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 962,
          title: "Ticket for label clear",
          labels: ["bug", "frontend"]
        })

      assert {:ok, updated} = ProjectTicketRepository.update_labels(962, [])
      assert updated.labels == []
    end

    test "returns {:error, :not_found} when ticket number doesn't exist" do
      assert {:error, :not_found} = ProjectTicketRepository.update_labels(99_999, ["bug"])
    end
  end
end
