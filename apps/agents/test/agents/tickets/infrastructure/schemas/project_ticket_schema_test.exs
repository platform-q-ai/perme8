defmodule Agents.Tickets.Infrastructure.Schemas.ProjectTicketSchemaTest do
  use Agents.DataCase, async: true

  alias Agents.Tickets.Infrastructure.Schemas.ProjectTicketSchema

  describe "changeset/2" do
    test "accepts parent_ticket_id as a castable field" do
      changeset =
        ProjectTicketSchema.changeset(%ProjectTicketSchema{}, %{
          number: 101,
          title: "Child ticket",
          parent_ticket_id: 42
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :parent_ticket_id) == 42
    end

    test "accepts nil parent_ticket_id for root tickets" do
      changeset =
        ProjectTicketSchema.changeset(%ProjectTicketSchema{}, %{
          number: 102,
          title: "Root ticket",
          parent_ticket_id: nil
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :parent_ticket_id) == nil
    end
  end

  describe "task_id field" do
    test "accepts task_id as a castable field" do
      task_id = Ecto.UUID.generate()

      changeset =
        ProjectTicketSchema.changeset(%ProjectTicketSchema{}, %{
          number: 103,
          title: "Ticket with task",
          task_id: task_id
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :task_id) == task_id
    end

    test "accepts nil task_id" do
      changeset =
        ProjectTicketSchema.changeset(%ProjectTicketSchema{}, %{
          number: 104,
          title: "Ticket without task",
          task_id: nil
        })

      assert changeset.valid?
    end
  end

  describe "schema associations" do
    test "defines parent_ticket belongs_to association" do
      association = ProjectTicketSchema.__schema__(:association, :parent_ticket)

      assert %Ecto.Association.BelongsTo{} = association
      assert association.owner_key == :parent_ticket_id
      assert association.related == ProjectTicketSchema
    end

    test "defines sub_tickets has_many association" do
      association = ProjectTicketSchema.__schema__(:association, :sub_tickets)

      assert %Ecto.Association.Has{} = association
      assert association.owner_key == :id
      assert association.related_key == :parent_ticket_id
      assert association.related == ProjectTicketSchema
    end

    test "defines lifecycle_events has_many association" do
      association = ProjectTicketSchema.__schema__(:association, :lifecycle_events)

      assert %Ecto.Association.Has{} = association
      assert association.owner_key == :id
      assert association.related_key == :ticket_id

      assert association.related ==
               Agents.Tickets.Infrastructure.Schemas.TicketLifecycleEventSchema
    end
  end

  describe "lifecycle fields" do
    test "includes lifecycle_stage and lifecycle_stage_entered_at fields" do
      assert :lifecycle_stage in ProjectTicketSchema.__schema__(:fields)
      assert :lifecycle_stage_entered_at in ProjectTicketSchema.__schema__(:fields)
      assert ProjectTicketSchema.__schema__(:type, :lifecycle_stage) == :string
      assert ProjectTicketSchema.__schema__(:type, :lifecycle_stage_entered_at) == :utc_datetime
    end

    test "changeset casts lifecycle fields" do
      entered_at = ~U[2026-03-11 10:00:00Z]

      changeset =
        ProjectTicketSchema.changeset(%ProjectTicketSchema{}, %{
          number: 105,
          title: "Lifecycle ticket",
          lifecycle_stage: "in_progress",
          lifecycle_stage_entered_at: entered_at
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :lifecycle_stage) == "in_progress"
      assert Ecto.Changeset.get_change(changeset, :lifecycle_stage_entered_at) == entered_at
    end

    test "changeset validates lifecycle_stage inclusion" do
      changeset =
        ProjectTicketSchema.changeset(%ProjectTicketSchema{}, %{
          number: 106,
          title: "Lifecycle ticket",
          lifecycle_stage: "bad_stage"
        })

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).lifecycle_stage
    end
  end
end
