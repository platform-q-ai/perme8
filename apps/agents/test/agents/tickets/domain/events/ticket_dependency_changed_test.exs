defmodule Agents.Tickets.Domain.Events.TicketDependencyChangedTest do
  use ExUnit.Case, async: true

  alias Agents.Tickets.Domain.Events.TicketDependencyChanged

  describe "new/1" do
    test "creates event with required fields for :added action" do
      event =
        TicketDependencyChanged.new(%{
          aggregate_id: "1",
          actor_id: "user-1",
          blocker_ticket_id: 1,
          blocked_ticket_id: 2,
          action: :added
        })

      assert event.blocker_ticket_id == 1
      assert event.blocked_ticket_id == 2
      assert event.action == :added
      assert event.aggregate_id == "1"
      assert event.actor_id == "user-1"
    end

    test "creates event with required fields for :removed action" do
      event =
        TicketDependencyChanged.new(%{
          aggregate_id: "1",
          actor_id: "user-1",
          blocker_ticket_id: 1,
          blocked_ticket_id: 2,
          action: :removed
        })

      assert event.action == :removed
    end
  end
end
