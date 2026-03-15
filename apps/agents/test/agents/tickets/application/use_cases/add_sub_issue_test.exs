defmodule Agents.Tickets.Application.UseCases.AddSubIssueTest do
  use Agents.DataCase, async: true

  alias Agents.Tickets.Application.UseCases.AddSubIssue
  alias Agents.Tickets.Domain.Events.TicketSubIssueChanged
  alias Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
  alias Perme8.Events.TestEventBus

  @actor_id "user-123"
  @default_opts [actor_id: @actor_id, event_bus: TestEventBus]

  setup do
    TestEventBus.start_global()

    {:ok, parent} =
      ProjectTicketRepository.sync_remote_ticket(%{number: 300, title: "Parent", state: "open"})

    {:ok, child} =
      ProjectTicketRepository.sync_remote_ticket(%{number: 301, title: "Child", state: "open"})

    %{parent: parent, child: child}
  end

  describe "execute/3" do
    test "sets parent_ticket_id on child", %{parent: parent, child: _child} do
      assert {:ok, schema} = AddSubIssue.execute(300, 301, @default_opts)
      assert schema.parent_ticket_id == parent.id
    end

    test "emits TicketSubIssueChanged event with :added action" do
      assert {:ok, _schema} = AddSubIssue.execute(300, 301, @default_opts)

      events = TestEventBus.get_events()
      assert [%TicketSubIssueChanged{} = event] = events
      assert event.parent_number == 300
      assert event.child_number == 301
      assert event.action == :added
      assert event.actor_id == @actor_id
    end

    test "returns error when child doesn't exist" do
      assert {:error, :child_not_found} = AddSubIssue.execute(300, 999, @default_opts)
      assert TestEventBus.get_events() == []
    end

    test "returns error when parent doesn't exist" do
      assert {:error, :parent_not_found} = AddSubIssue.execute(999, 301, @default_opts)
      assert TestEventBus.get_events() == []
    end
  end
end
