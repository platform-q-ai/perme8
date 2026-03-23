defmodule Agents.Sessions.Application.UseCases.TerminateTicketSessionTest do
  use Agents.DataCase, async: false

  import Mox

  alias Agents.Repo
  alias Agents.Sessions.Application.UseCases.TerminateTicketSession
  alias Agents.Sessions.Infrastructure.Schemas.SessionSchema
  alias Agents.Tickets.Infrastructure.Schemas.ProjectTicketSchema

  setup :verify_on_exit!

  defp insert_session(attrs \\ %{}) do
    defaults = %{
      user_id: Ecto.UUID.generate(),
      title: "Ticket session",
      status: "active",
      container_status: "running",
      container_id: "ticket-container"
    }

    %SessionSchema{}
    |> SessionSchema.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  defp insert_ticket(number, attrs \\ %{}) do
    defaults = %{
      number: number,
      title: "Ticket ##{number}",
      state: "open",
      labels: [],
      position: 0,
      created_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    %ProjectTicketSchema{}
    |> ProjectTicketSchema.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  test "terminates linked session and unlinks ticket" do
    session = insert_session()
    _ticket = insert_ticket(507, %{session_id: session.id})

    Agents.Mocks.ContainerProviderMock
    |> expect(:remove, fn "ticket-container" -> :ok end)

    assert :ok =
             TerminateTicketSession.execute(507,
               container_provider: Agents.Mocks.ContainerProviderMock
             )

    refreshed_session = Repo.get!(SessionSchema, session.id)
    assert refreshed_session.status == "terminated"
    assert refreshed_session.container_status == "removed"

    refreshed_ticket = Repo.get_by!(ProjectTicketSchema, number: 507)
    assert is_nil(refreshed_ticket.session_id)
  end

  test "is idempotent when ticket has no linked session" do
    _ticket = insert_ticket(508)

    assert :ok =
             TerminateTicketSession.execute(508,
               container_provider: Agents.Mocks.ContainerProviderMock
             )
  end
end
