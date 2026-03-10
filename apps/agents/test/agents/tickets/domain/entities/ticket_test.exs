defmodule Agents.Tickets.Domain.Entities.TicketTest do
  use ExUnit.Case, async: true

  alias Agents.Tickets.Domain.Entities.Ticket

  describe "Ticket.new/1" do
    test "creates a ticket struct with all fields" do
      ticket = Ticket.new(%{number: 382, title: "Parent ticket"})

      assert %Ticket{} = ticket
      assert Map.has_key?(ticket, :id)
      assert Map.has_key?(ticket, :number)
      assert Map.has_key?(ticket, :external_id)
      assert Map.has_key?(ticket, :title)
      assert Map.has_key?(ticket, :body)
      assert Map.has_key?(ticket, :status)
      assert Map.has_key?(ticket, :state)
      assert Map.has_key?(ticket, :priority)
      assert Map.has_key?(ticket, :size)
      assert Map.has_key?(ticket, :labels)
      assert Map.has_key?(ticket, :url)
      assert Map.has_key?(ticket, :position)
      assert Map.has_key?(ticket, :sync_state)
      assert Map.has_key?(ticket, :last_synced_at)
      assert Map.has_key?(ticket, :last_sync_error)
      assert Map.has_key?(ticket, :remote_updated_at)
      assert Map.has_key?(ticket, :parent_ticket_id)
      assert Map.has_key?(ticket, :sub_tickets)
      assert Map.has_key?(ticket, :created_at)
      assert Map.has_key?(ticket, :inserted_at)
      assert Map.has_key?(ticket, :updated_at)
      assert Map.has_key?(ticket, :associated_task_id)
      assert Map.has_key?(ticket, :associated_container_id)
      assert Map.has_key?(ticket, :session_state)
      assert Map.has_key?(ticket, :task_status)
      assert Map.has_key?(ticket, :task_error)
    end

    test "sets expected defaults" do
      ticket = Ticket.new(%{number: 382, title: "Parent ticket"})

      assert ticket.state == "open"
      assert ticket.labels == []
      assert ticket.sub_tickets == []
      assert ticket.position == 0
      assert ticket.sync_state == "synced"
      assert ticket.session_state == "idle"
    end

    test "allows overriding defaults" do
      ticket =
        Ticket.new(%{
          number: 382,
          title: "Parent ticket",
          state: "closed",
          labels: ["bug"],
          sub_tickets: [%{number: 383}],
          position: 42,
          sync_state: "failed",
          session_state: "running"
        })

      assert ticket.state == "closed"
      assert ticket.labels == ["bug"]
      assert ticket.sub_tickets == [%{number: 383}]
      assert ticket.position == 42
      assert ticket.sync_state == "failed"
      assert ticket.session_state == "running"
    end
  end

  describe "Ticket.from_schema/1" do
    test "maps all schema fields explicitly" do
      schema = %{
        __struct__: SomeSchema,
        id: 1,
        number: 382,
        external_id: "I_kwDOLg0VD86cJxM_",
        title: "Parent ticket",
        body: "Body",
        status: "Todo",
        state: "open",
        priority: "high",
        size: "M",
        labels: ["backend", "bug"],
        url: "https://github.com/platform-q-ai/perme8/issues/382",
        position: 10,
        sync_state: "synced",
        last_synced_at: ~U[2026-03-08 10:00:00.000000Z],
        last_sync_error: nil,
        remote_updated_at: ~U[2026-03-08 09:59:00.000000Z],
        parent_ticket_id: nil,
        sub_tickets: [],
        created_at: ~U[2026-03-07 08:00:00.000000Z],
        inserted_at: ~U[2026-03-08 08:00:00.000000Z],
        updated_at: ~U[2026-03-08 08:30:00.000000Z]
      }

      ticket = Ticket.from_schema(schema)

      assert ticket.id == 1
      assert ticket.number == 382
      assert ticket.external_id == "I_kwDOLg0VD86cJxM_"
      assert ticket.title == "Parent ticket"
      assert ticket.body == "Body"
      assert ticket.status == "Todo"
      assert ticket.state == "open"
      assert ticket.priority == "high"
      assert ticket.size == "M"
      assert ticket.labels == ["backend", "bug"]
      assert ticket.url == "https://github.com/platform-q-ai/perme8/issues/382"
      assert ticket.position == 10
      assert ticket.sync_state == "synced"
      assert ticket.last_synced_at == ~U[2026-03-08 10:00:00.000000Z]
      assert ticket.last_sync_error == nil
      assert ticket.remote_updated_at == ~U[2026-03-08 09:59:00.000000Z]
      assert ticket.parent_ticket_id == nil
      assert ticket.sub_tickets == []
      assert ticket.created_at == ~U[2026-03-07 08:00:00.000000Z]
      assert ticket.inserted_at == ~U[2026-03-08 08:00:00.000000Z]
      assert ticket.updated_at == ~U[2026-03-08 08:30:00.000000Z]
      assert ticket.associated_task_id == nil
      assert ticket.associated_container_id == nil
      assert ticket.session_state == "idle"
      assert ticket.task_status == nil
      assert ticket.task_error == nil
    end

    test "reads persisted task_id into associated_task_id" do
      task_id = Ecto.UUID.generate()

      schema = %{
        __struct__: SomeSchema,
        id: 1,
        number: 382,
        external_id: "I_kwDOLg0VD86cJxM_",
        title: "Parent ticket",
        body: nil,
        status: "Todo",
        state: "open",
        priority: nil,
        size: nil,
        labels: [],
        url: nil,
        position: 0,
        sync_state: "synced",
        last_synced_at: nil,
        last_sync_error: nil,
        remote_updated_at: nil,
        parent_ticket_id: nil,
        sub_tickets: [],
        created_at: nil,
        inserted_at: nil,
        updated_at: nil,
        task_id: task_id
      }

      ticket = Ticket.from_schema(schema)

      assert ticket.associated_task_id == task_id
      assert ticket.associated_container_id == nil
      assert ticket.session_state == "idle"
    end

    test "associated_task_id is nil when schema has no task_id key" do
      schema = %{
        __struct__: SomeSchema,
        id: 1,
        number: 382,
        external_id: nil,
        title: "No task_id key",
        body: nil,
        status: nil,
        state: "open",
        priority: nil,
        size: nil,
        labels: [],
        url: nil,
        position: 0,
        sync_state: "synced",
        last_synced_at: nil,
        last_sync_error: nil,
        remote_updated_at: nil,
        parent_ticket_id: nil,
        sub_tickets: [],
        created_at: nil,
        inserted_at: nil,
        updated_at: nil
      }

      ticket = Ticket.from_schema(schema)
      assert ticket.associated_task_id == nil
    end

    test "recursively converts preloaded sub_tickets" do
      sub_schema = %{
        __struct__: SomeSchema,
        id: 2,
        number: 383,
        external_id: "sub-383",
        title: "Sub ticket",
        body: nil,
        status: "Todo",
        state: "open",
        priority: nil,
        size: nil,
        labels: [],
        url: "https://github.com/platform-q-ai/perme8/issues/383",
        position: 1,
        sync_state: "synced",
        last_synced_at: nil,
        last_sync_error: nil,
        remote_updated_at: nil,
        parent_ticket_id: 1,
        sub_tickets: [],
        created_at: nil,
        inserted_at: nil,
        updated_at: nil
      }

      schema = %{
        __struct__: SomeSchema,
        id: 1,
        number: 382,
        external_id: "parent-382",
        title: "Parent",
        body: nil,
        status: "Todo",
        state: "open",
        priority: nil,
        size: nil,
        labels: [],
        url: "https://github.com/platform-q-ai/perme8/issues/382",
        position: 0,
        sync_state: "synced",
        last_synced_at: nil,
        last_sync_error: nil,
        remote_updated_at: nil,
        parent_ticket_id: nil,
        sub_tickets: [sub_schema],
        created_at: nil,
        inserted_at: nil,
        updated_at: nil
      }

      ticket = Ticket.from_schema(schema)

      assert [%Ticket{} = sub_ticket] = ticket.sub_tickets
      assert sub_ticket.number == 383
      assert sub_ticket.parent_ticket_id == 1
    end

    test "defaults sub_tickets to [] when association is not loaded" do
      schema = %{
        __struct__: SomeSchema,
        id: 1,
        number: 382,
        external_id: "parent-382",
        title: "Parent",
        body: nil,
        status: "Todo",
        state: "open",
        priority: nil,
        size: nil,
        labels: [],
        url: nil,
        position: 0,
        sync_state: "synced",
        last_synced_at: nil,
        last_sync_error: nil,
        remote_updated_at: nil,
        parent_ticket_id: nil,
        sub_tickets: %Ecto.Association.NotLoaded{
          __field__: :sub_tickets,
          __owner__: SomeSchema,
          __cardinality__: :many
        },
        created_at: nil,
        inserted_at: nil,
        updated_at: nil
      }

      ticket = Ticket.from_schema(schema)
      assert ticket.sub_tickets == []
    end

    test "keeps nil parent_ticket_id for root tickets" do
      schema = %{
        __struct__: SomeSchema,
        id: 1,
        number: 382,
        external_id: "parent-382",
        title: "Parent",
        body: nil,
        status: "Todo",
        state: "open",
        priority: nil,
        size: nil,
        labels: [],
        url: nil,
        position: 0,
        sync_state: "synced",
        last_synced_at: nil,
        last_sync_error: nil,
        remote_updated_at: nil,
        parent_ticket_id: nil,
        sub_tickets: [],
        created_at: nil,
        inserted_at: nil,
        updated_at: nil
      }

      ticket = Ticket.from_schema(schema)
      assert ticket.parent_ticket_id == nil
    end
  end

  describe "domain query helpers" do
    test "open?/1 returns true for open tickets" do
      assert Ticket.open?(Ticket.new(%{state: "open"}))
      refute Ticket.open?(Ticket.new(%{state: "closed"}))
    end

    test "closed?/1 returns true for closed tickets" do
      assert Ticket.closed?(Ticket.new(%{state: "closed"}))
      refute Ticket.closed?(Ticket.new(%{state: "open"}))
    end

    test "has_sub_tickets?/1 detects populated sub_tickets" do
      assert Ticket.has_sub_tickets?(Ticket.new(%{sub_tickets: [%Ticket{number: 1}]}))
      refute Ticket.has_sub_tickets?(Ticket.new(%{sub_tickets: []}))
      refute Ticket.has_sub_tickets?(Ticket.new(%{sub_tickets: nil}))
    end

    test "root_ticket?/1 and sub_ticket?/1 identify hierarchy position" do
      root = Ticket.new(%{parent_ticket_id: nil})
      child = Ticket.new(%{parent_ticket_id: 123})

      assert Ticket.root_ticket?(root)
      refute Ticket.sub_ticket?(root)
      refute Ticket.root_ticket?(child)
      assert Ticket.sub_ticket?(child)
    end
  end

  describe "valid_states/0" do
    test "returns open and closed" do
      assert Ticket.valid_states() == ["open", "closed"]
    end
  end

  describe "build_context_block/1" do
    test "formats a ticket context block with all sections" do
      ticket =
        Ticket.new(%{
          id: 10,
          number: 42,
          title: "Fix session context",
          labels: ["bug", "tickets"],
          body: "Detailed reproduction and expected behavior.",
          sub_tickets: [
            Ticket.new(%{number: 43, title: "Add tests"}),
            %{number: 44, title: "Ship fix"}
          ]
        })

      block = Ticket.build_context_block(ticket)

      assert block =~ "## Ticket #42: Fix session context"
      assert block =~ "Labels: #bug #tickets"
      assert block =~ "Body:\nDetailed reproduction and expected behavior."
      assert block =~ "Sub-tickets:"
      assert block =~ "- #43: Add tests"
      assert block =~ "- #44: Ship fix"
    end

    test "omits optional sections when labels, body, and sub_tickets are empty" do
      ticket =
        Ticket.new(%{
          number: 50,
          title: "Minimal ticket",
          labels: [],
          body: nil,
          sub_tickets: []
        })

      block = Ticket.build_context_block(ticket)

      assert block =~ "## Ticket #50: Minimal ticket"
      refute block =~ "Labels:"
      refute block =~ "Body:"
      refute block =~ "Sub-tickets:"
    end

    test "includes parent reference for sub-tickets" do
      ticket =
        Ticket.new(%{
          number: 51,
          title: "Child ticket",
          parent_ticket_id: 999
        })

      block = Ticket.build_context_block(ticket)

      assert block =~ "## Ticket #51: Child ticket"
      assert block =~ "Parent: ticket_id=999"
    end
  end
end
