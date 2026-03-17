defmodule Agents.Tickets.LinkSessionTest do
  use Agents.DataCase, async: false

  alias Agents.Tickets
  alias Agents.Tickets.Infrastructure.Schemas.ProjectTicketSchema
  alias Agents.Sessions.Infrastructure.Schemas.SessionSchema
  alias Agents.Repo

  defp create_session do
    %SessionSchema{}
    |> SessionSchema.changeset(%{
      user_id: Ecto.UUID.generate(),
      title: "Test session",
      status: "active",
      container_status: "pending"
    })
    |> Repo.insert!()
  end

  defp create_ticket(number) do
    %ProjectTicketSchema{}
    |> ProjectTicketSchema.changeset(%{
      number: number,
      title: "Test ticket ##{number}",
      state: "open",
      labels: [],
      position: 0,
      created_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.insert!()
  end

  describe "link_ticket_to_session/2" do
    test "delegates to repository and sets session_id" do
      session = create_session()
      create_ticket(50)

      assert {:ok, updated} = Tickets.link_ticket_to_session(50, session.id)
      assert updated.session_id == session.id
    end

    test "returns error when ticket not found" do
      session = create_session()
      assert {:error, :ticket_not_found} = Tickets.link_ticket_to_session(9999, session.id)
    end
  end

  describe "unlink_ticket_from_session/1" do
    test "delegates to repository and clears session_id" do
      session = create_session()
      create_ticket(51)
      {:ok, _} = Tickets.link_ticket_to_session(51, session.id)

      assert {:ok, updated} = Tickets.unlink_ticket_from_session(51)
      assert is_nil(updated.session_id)
    end

    test "returns error when ticket not found" do
      assert {:error, :ticket_not_found} = Tickets.unlink_ticket_from_session(9999)
    end
  end
end
