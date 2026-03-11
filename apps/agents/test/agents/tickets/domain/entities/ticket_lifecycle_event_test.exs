defmodule Agents.Tickets.Domain.Entities.TicketLifecycleEventTest do
  use ExUnit.Case, async: true

  alias Agents.Tickets.Domain.Entities.TicketLifecycleEvent

  describe "new/1" do
    test "creates a struct with all fields" do
      attrs = %{
        id: 10,
        ticket_id: 402,
        from_stage: "open",
        to_stage: "in_progress",
        transitioned_at: ~U[2026-03-10 10:00:00Z],
        trigger: "manual",
        inserted_at: ~U[2026-03-10 10:00:05Z]
      }

      event = TicketLifecycleEvent.new(attrs)

      assert event.id == 10
      assert event.ticket_id == 402
      assert event.from_stage == "open"
      assert event.to_stage == "in_progress"
      assert event.transitioned_at == ~U[2026-03-10 10:00:00Z]
      assert event.trigger == "manual"
      assert event.inserted_at == ~U[2026-03-10 10:00:05Z]
    end

    test "handles nil fields gracefully" do
      event = TicketLifecycleEvent.new(%{ticket_id: 402, to_stage: "open"})

      assert event.id == nil
      assert event.from_stage == nil
      assert event.inserted_at == nil
      assert event.trigger == "system"
    end
  end

  describe "from_schema/1" do
    test "converts a schema-like struct and maps all fields" do
      schema = %{
        __struct__: SomeSchema,
        id: 11,
        ticket_id: 403,
        from_stage: "ready",
        to_stage: "in_progress",
        transitioned_at: ~U[2026-03-10 11:00:00Z],
        trigger: "sync",
        inserted_at: ~U[2026-03-10 11:00:01Z]
      }

      event = TicketLifecycleEvent.from_schema(schema)

      assert event.id == 11
      assert event.ticket_id == 403
      assert event.from_stage == "ready"
      assert event.to_stage == "in_progress"
      assert event.transitioned_at == ~U[2026-03-10 11:00:00Z]
      assert event.trigger == "sync"
      assert event.inserted_at == ~U[2026-03-10 11:00:01Z]
    end

    test "uses default trigger when schema trigger is nil" do
      schema = %{
        __struct__: SomeSchema,
        id: 12,
        ticket_id: 404,
        from_stage: "open",
        to_stage: "ready",
        transitioned_at: ~U[2026-03-10 12:00:00Z],
        trigger: nil,
        inserted_at: ~U[2026-03-10 12:00:01Z]
      }

      event = TicketLifecycleEvent.from_schema(schema)
      assert event.trigger == "system"
    end
  end
end
