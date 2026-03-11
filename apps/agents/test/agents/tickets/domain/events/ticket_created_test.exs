defmodule Agents.Tickets.Domain.Events.TicketCreatedTest do
  use ExUnit.Case, async: true

  alias Agents.Tickets.Domain.Events.TicketCreated

  @valid_attrs %{
    aggregate_id: "42",
    actor_id: "user-123",
    ticket_id: 42,
    title: "Fix login bug"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert TicketCreated.event_type() == "tickets.ticket_created"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert TicketCreated.aggregate_type() == "ticket"
    end
  end

  describe "new/1" do
    test "creates event with required fields" do
      event = TicketCreated.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "tickets.ticket_created"
      assert event.aggregate_type == "ticket"
      assert event.ticket_id == 42
      assert event.title == "Fix login bug"
      assert event.body == nil
    end

    test "creates event with optional body" do
      event = TicketCreated.new(Map.put(@valid_attrs, :body, "Detailed description"))

      assert event.body == "Detailed description"
    end

    test "auto-generates event_id and occurred_at" do
      event = TicketCreated.new(@valid_attrs)

      assert is_binary(event.event_id)
      assert %DateTime{} = event.occurred_at
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        TicketCreated.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end

    test "raises when title is missing" do
      assert_raise ArgumentError, fn ->
        TicketCreated.new(%{aggregate_id: "123", actor_id: "123", ticket_id: 1})
      end
    end
  end
end
