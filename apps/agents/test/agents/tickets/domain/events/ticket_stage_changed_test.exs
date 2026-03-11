defmodule Agents.Tickets.Domain.Events.TicketStageChangedTest do
  use ExUnit.Case, async: true

  alias Agents.Tickets.Domain.Events.TicketStageChanged

  @valid_attrs %{
    aggregate_id: "402",
    actor_id: "system",
    ticket_id: 402,
    from_stage: "open",
    to_stage: "ready"
  }

  test "creates event with required fields" do
    event = TicketStageChanged.new(@valid_attrs)

    assert event.ticket_id == 402
    assert event.from_stage == "open"
    assert event.to_stage == "ready"
    assert event.trigger == "system"
  end

  test "allows optional trigger override" do
    event = TicketStageChanged.new(Map.put(@valid_attrs, :trigger, "manual"))
    assert event.trigger == "manual"
  end

  test "has ticket aggregate type and domain event metadata" do
    event = TicketStageChanged.new(@valid_attrs)

    assert TicketStageChanged.aggregate_type() == "ticket"
    assert TicketStageChanged.event_type() == "tickets.ticket_stage_changed"
    assert is_binary(event.event_id)
    assert %DateTime{} = event.occurred_at
    assert is_map(event.metadata)
  end

  test "raises when required fields are missing" do
    assert_raise ArgumentError, fn ->
      TicketStageChanged.new(%{aggregate_id: "402", actor_id: "system", ticket_id: 402})
    end
  end
end
