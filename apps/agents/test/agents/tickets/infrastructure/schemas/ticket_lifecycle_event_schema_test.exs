defmodule Agents.Tickets.Infrastructure.Schemas.TicketLifecycleEventSchemaTest do
  use Agents.DataCase

  alias Agents.Tickets.Infrastructure.Schemas.TicketLifecycleEventSchema

  describe "changeset/2" do
    test "is valid with required fields" do
      changeset =
        TicketLifecycleEventSchema.changeset(%TicketLifecycleEventSchema{}, %{
          ticket_id: 1,
          to_stage: "open",
          transitioned_at: ~U[2026-03-11 10:00:00Z],
          trigger: "sync"
        })

      assert changeset.valid?
    end

    test "is invalid when to_stage is missing" do
      changeset =
        TicketLifecycleEventSchema.changeset(%TicketLifecycleEventSchema{}, %{
          ticket_id: 1,
          transitioned_at: ~U[2026-03-11 10:00:00Z],
          trigger: "system"
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).to_stage
    end

    test "is invalid when ticket_id is missing" do
      changeset =
        TicketLifecycleEventSchema.changeset(%TicketLifecycleEventSchema{}, %{
          to_stage: "open",
          transitioned_at: ~U[2026-03-11 10:00:00Z],
          trigger: "system"
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).ticket_id
    end

    test "defaults trigger to system when omitted" do
      event =
        %TicketLifecycleEventSchema{}
        |> TicketLifecycleEventSchema.changeset(%{
          ticket_id: 1,
          to_stage: "open",
          transitioned_at: ~U[2026-03-11 10:00:00Z]
        })
        |> Ecto.Changeset.apply_changes()

      assert event.trigger == "system"
    end

    test "accepts system sync and manual triggers" do
      for trigger <- ["system", "sync", "manual"] do
        changeset =
          TicketLifecycleEventSchema.changeset(%TicketLifecycleEventSchema{}, %{
            ticket_id: 1,
            to_stage: "open",
            transitioned_at: ~U[2026-03-11 10:00:00Z],
            trigger: trigger
          })

        assert changeset.valid?
      end
    end
  end
end
