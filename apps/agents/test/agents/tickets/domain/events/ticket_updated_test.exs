defmodule Agents.Tickets.Domain.Events.TicketUpdatedTest do
  use ExUnit.Case, async: true

  alias Agents.Tickets.Domain.Events.TicketUpdated

  describe "new/1" do
    test "creates event with required fields" do
      event =
        TicketUpdated.new(%{
          aggregate_id: "42",
          actor_id: "user-1",
          ticket_id: 42,
          number: 100,
          changes: %{title: "New title"}
        })

      assert %TicketUpdated{} = event
      assert event.ticket_id == 42
      assert event.number == 100
      assert event.changes == %{title: "New title"}
      assert event.aggregate_type == "ticket"
    end

    test "validates required fields" do
      assert_raise ArgumentError, fn ->
        TicketUpdated.new(%{aggregate_id: "42", actor_id: "user-1"})
      end
    end
  end
end
