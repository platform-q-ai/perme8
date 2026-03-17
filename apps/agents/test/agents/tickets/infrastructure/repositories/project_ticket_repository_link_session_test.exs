defmodule Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepositoryLinkSessionTest do
  use Agents.DataCase, async: false

  alias Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
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

  describe "link_session/2" do
    test "sets session_id on the ticket matching the given number" do
      session = create_session()
      ticket = create_ticket(42)

      assert {:ok, updated} = ProjectTicketRepository.link_session(42, session.id)
      assert updated.session_id == session.id
      assert updated.id == ticket.id
    end

    test "returns {:error, :ticket_not_found} when ticket does not exist" do
      session = create_session()

      assert {:error, :ticket_not_found} =
               ProjectTicketRepository.link_session(9999, session.id)
    end
  end

  describe "unlink_session/1" do
    test "clears session_id on the ticket" do
      session = create_session()
      create_ticket(43)
      {:ok, _} = ProjectTicketRepository.link_session(43, session.id)

      assert {:ok, updated} = ProjectTicketRepository.unlink_session(43)
      assert is_nil(updated.session_id)
    end

    test "returns {:error, :ticket_not_found} when ticket does not exist" do
      assert {:error, :ticket_not_found} = ProjectTicketRepository.unlink_session(9999)
    end
  end
end
