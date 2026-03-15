defmodule Agents.Tickets.Domain.Events.TicketSubIssueChangedTest do
  use ExUnit.Case, async: true

  alias Agents.Tickets.Domain.Events.TicketSubIssueChanged

  describe "new/1" do
    test "creates event for added action" do
      event =
        TicketSubIssueChanged.new(%{
          aggregate_id: "100",
          actor_id: "user-1",
          parent_number: 100,
          child_number: 101,
          action: :added
        })

      assert %TicketSubIssueChanged{} = event
      assert event.parent_number == 100
      assert event.child_number == 101
      assert event.action == :added
      assert event.aggregate_type == "ticket"
    end

    test "creates event for removed action" do
      event =
        TicketSubIssueChanged.new(%{
          aggregate_id: "100",
          actor_id: "user-1",
          parent_number: 100,
          child_number: 101,
          action: :removed
        })

      assert event.action == :removed
    end
  end
end
