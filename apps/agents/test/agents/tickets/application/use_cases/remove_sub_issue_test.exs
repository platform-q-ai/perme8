defmodule Agents.Tickets.Application.UseCases.RemoveSubIssueTest do
  use Agents.DataCase, async: true

  alias Agents.Tickets.Application.UseCases.RemoveSubIssue
  alias Agents.Tickets.Domain.Events.TicketSubIssueChanged
  alias Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
  alias Perme8.Events.TestEventBus

  @actor_id "user-123"
  @default_opts [actor_id: @actor_id, event_bus: TestEventBus]

  setup do
    TestEventBus.start_global()

    {:ok, parent} =
      ProjectTicketRepository.sync_remote_ticket(%{number: 400, title: "Parent", state: "open"})

    {:ok, _child} =
      ProjectTicketRepository.sync_remote_ticket(%{number: 401, title: "Child", state: "open"})

    # Link child to parent
    {:ok, _linked} = ProjectTicketRepository.set_parent_ticket(401, 400)

    %{parent: parent}
  end

  describe "execute/3" do
    test "clears parent_ticket_id on child" do
      assert {:ok, schema} = RemoveSubIssue.execute(400, 401, @default_opts)
      assert is_nil(schema.parent_ticket_id)
    end

    test "emits TicketSubIssueChanged event with :removed action" do
      assert {:ok, _schema} = RemoveSubIssue.execute(400, 401, @default_opts)

      events = TestEventBus.get_events()
      assert [%TicketSubIssueChanged{} = event] = events
      assert event.parent_number == 400
      assert event.child_number == 401
      assert event.action == :removed
      assert event.actor_id == @actor_id
    end

    test "returns error when child doesn't exist" do
      assert {:error, :not_found} = RemoveSubIssue.execute(400, 999, @default_opts)
      assert TestEventBus.get_events() == []
    end
  end
end
