defmodule Agents.Tickets.Infrastructure.Schemas.TicketDependencySchemaTest do
  use Agents.DataCase, async: true

  alias Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
  alias Agents.Tickets.Infrastructure.Schemas.TicketDependencySchema

  setup do
    {:ok, ticket_a} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 500,
        title: "Schema Test A",
        state: "open"
      })

    {:ok, ticket_b} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 501,
        title: "Schema Test B",
        state: "open"
      })

    %{ticket_a: ticket_a, ticket_b: ticket_b}
  end

  describe "changeset/2" do
    test "valid changeset with required fields", %{ticket_a: a, ticket_b: b} do
      changeset =
        TicketDependencySchema.changeset(%{
          blocker_ticket_id: a.id,
          blocked_ticket_id: b.id
        })

      assert changeset.valid?
    end

    test "rejects missing blocker_ticket_id", %{ticket_b: b} do
      changeset = TicketDependencySchema.changeset(%{blocked_ticket_id: b.id})
      refute changeset.valid?
      assert %{blocker_ticket_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects missing blocked_ticket_id", %{ticket_a: a} do
      changeset = TicketDependencySchema.changeset(%{blocker_ticket_id: a.id})
      refute changeset.valid?
      assert %{blocked_ticket_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects self-referencing dependency", %{ticket_a: a} do
      changeset =
        TicketDependencySchema.changeset(%{
          blocker_ticket_id: a.id,
          blocked_ticket_id: a.id
        })

      refute changeset.valid?
      assert %{blocked_ticket_id: ["cannot be the same as blocker ticket"]} = errors_on(changeset)
    end

    test "rejects duplicate dependency via unique constraint", %{ticket_a: a, ticket_b: b} do
      {:ok, _} =
        TicketDependencySchema.changeset(%{blocker_ticket_id: a.id, blocked_ticket_id: b.id})
        |> Agents.Repo.insert()

      {:error, changeset} =
        TicketDependencySchema.changeset(%{blocker_ticket_id: a.id, blocked_ticket_id: b.id})
        |> Agents.Repo.insert()

      assert %{blocker_ticket_id: ["has already been taken"]} = errors_on(changeset)
    end
  end
end
