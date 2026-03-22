defmodule Agents.Tickets.Domain.Events.TicketClosedTest do
  use ExUnit.Case, async: true

  alias Agents.Tickets.Domain.Events.TicketClosed

  @valid_attrs %{
    aggregate_id: "42",
    actor_id: "user-123",
    ticket_id: 42,
    number: 506
  }

  test "event_type/0 returns correct type" do
    assert TicketClosed.event_type() == "tickets.ticket_closed"
  end

  test "aggregate_type/0 returns correct aggregate type" do
    assert TicketClosed.aggregate_type() == "ticket"
  end

  test "new/1 builds event with required fields" do
    event = TicketClosed.new(@valid_attrs)

    assert event.ticket_id == 42
    assert event.number == 506
    assert event.aggregate_type == "ticket"
    assert event.event_type == "tickets.ticket_closed"
    assert is_binary(event.event_id)
    assert %DateTime{} = event.occurred_at
  end

  test "new/1 raises when required fields are missing" do
    assert_raise ArgumentError, fn ->
      TicketClosed.new(%{aggregate_id: "42", actor_id: "user-123"})
    end
  end
end
