defmodule Agents.Sessions.Infrastructure.Schemas.ProjectTicketSchemaTest do
  use Agents.DataCase, async: true

  alias Agents.Sessions.Infrastructure.Schemas.ProjectTicketSchema

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
  end
end
