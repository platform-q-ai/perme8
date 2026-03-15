defmodule Agents.Tickets.Application.UseCases.AddTicketDependencyTest do
  use Agents.DataCase, async: true

  alias Agents.Tickets.Application.UseCases.AddTicketDependency
  alias Agents.Tickets.Domain.Events.TicketDependencyChanged
  alias Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
  alias Perme8.Events.TestEventBus

  @actor_id "user-123"
  @default_opts [actor_id: @actor_id, event_bus: TestEventBus]

  setup do
    TestEventBus.start_global()

    {:ok, ticket_a} =
      ProjectTicketRepository.sync_remote_ticket(%{number: 100, title: "Ticket A", state: "open"})

    {:ok, ticket_b} =
      ProjectTicketRepository.sync_remote_ticket(%{number: 101, title: "Ticket B", state: "open"})

    {:ok, ticket_c} =
      ProjectTicketRepository.sync_remote_ticket(%{number: 102, title: "Ticket C", state: "open"})

    %{ticket_a: ticket_a, ticket_b: ticket_b, ticket_c: ticket_c}
  end

  describe "execute/3" do
    test "successfully adds a dependency", %{ticket_a: a, ticket_b: b} do
      assert {:ok, dep} = AddTicketDependency.execute(a.id, b.id, @default_opts)
      assert dep.blocker_ticket_id == a.id
      assert dep.blocked_ticket_id == b.id
    end

    test "emits TicketDependencyChanged event with action :added", %{ticket_a: a, ticket_b: b} do
      assert {:ok, _dep} = AddTicketDependency.execute(a.id, b.id, @default_opts)

      events = TestEventBus.get_events()
      assert [%TicketDependencyChanged{} = event] = events
      assert event.blocker_ticket_id == a.id
      assert event.blocked_ticket_id == b.id
      assert event.action == :added
      assert event.actor_id == @actor_id
    end

    test "rejects self-dependency", %{ticket_a: a} do
      assert {:error, :self_dependency} = AddTicketDependency.execute(a.id, a.id, @default_opts)
      assert TestEventBus.get_events() == []
    end

    test "rejects duplicate dependency", %{ticket_a: a, ticket_b: b} do
      assert {:ok, _} = AddTicketDependency.execute(a.id, b.id, @default_opts)
      TestEventBus.start_global()

      assert {:error, :duplicate_dependency} =
               AddTicketDependency.execute(a.id, b.id, @default_opts)
    end

    test "rejects circular dependency (simple)", %{ticket_a: a, ticket_b: b} do
      assert {:ok, _} = AddTicketDependency.execute(a.id, b.id, @default_opts)
      TestEventBus.start_global()

      assert {:error, :circular_dependency} =
               AddTicketDependency.execute(b.id, a.id, @default_opts)
    end

    test "rejects circular dependency (transitive)", %{ticket_a: a, ticket_b: b, ticket_c: c} do
      assert {:ok, _} = AddTicketDependency.execute(a.id, b.id, @default_opts)
      assert {:ok, _} = AddTicketDependency.execute(b.id, c.id, @default_opts)
      TestEventBus.start_global()

      assert {:error, :circular_dependency} =
               AddTicketDependency.execute(c.id, a.id, @default_opts)
    end

    test "rejects non-existent blocker ticket", %{ticket_b: b} do
      assert {:error, :blocker_not_found} =
               AddTicketDependency.execute(999_999, b.id, @default_opts)
    end

    test "rejects non-existent blocked ticket", %{ticket_a: a} do
      assert {:error, :blocked_not_found} =
               AddTicketDependency.execute(a.id, 999_999, @default_opts)
    end
  end
end
