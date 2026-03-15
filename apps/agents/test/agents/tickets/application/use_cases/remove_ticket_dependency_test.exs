defmodule Agents.Tickets.Application.UseCases.RemoveTicketDependencyTest do
  use Agents.DataCase, async: true

  alias Agents.Tickets.Application.UseCases.RemoveTicketDependency
  alias Agents.Tickets.Domain.Events.TicketDependencyChanged
  alias Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
  alias Agents.Tickets.Infrastructure.Repositories.TicketDependencyRepository
  alias Perme8.Events.TestEventBus

  @actor_id "user-123"
  @default_opts [actor_id: @actor_id, event_bus: TestEventBus]

  setup do
    TestEventBus.start_global()

    {:ok, ticket_a} =
      ProjectTicketRepository.sync_remote_ticket(%{number: 200, title: "Ticket A", state: "open"})

    {:ok, ticket_b} =
      ProjectTicketRepository.sync_remote_ticket(%{number: 201, title: "Ticket B", state: "open"})

    {:ok, _dep} = TicketDependencyRepository.add_dependency(ticket_a.id, ticket_b.id)

    %{ticket_a: ticket_a, ticket_b: ticket_b}
  end

  describe "execute/3" do
    test "successfully removes a dependency", %{ticket_a: a, ticket_b: b} do
      assert :ok = RemoveTicketDependency.execute(a.id, b.id, @default_opts)
    end

    test "emits TicketDependencyChanged event with action :removed", %{ticket_a: a, ticket_b: b} do
      assert :ok = RemoveTicketDependency.execute(a.id, b.id, @default_opts)

      events = TestEventBus.get_events()
      assert [%TicketDependencyChanged{} = event] = events
      assert event.blocker_ticket_id == a.id
      assert event.blocked_ticket_id == b.id
      assert event.action == :removed
    end

    test "returns error for non-existent dependency", %{ticket_a: a, ticket_b: b} do
      # Remove it first
      assert :ok = RemoveTicketDependency.execute(a.id, b.id, @default_opts)
      TestEventBus.start_global()

      # Try again
      assert {:error, :dependency_not_found} =
               RemoveTicketDependency.execute(a.id, b.id, @default_opts)
    end
  end
end
