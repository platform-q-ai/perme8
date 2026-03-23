defmodule Agents.Sessions.Infrastructure.Subscribers.TicketSessionTerminationHandlerIntegrationTest do
  use Agents.DataCase, async: false

  import Mox

  alias Agents.Repo
  alias Agents.Sessions.Application.UseCases.TerminateTicketSession
  alias Agents.Sessions.Infrastructure.Schemas.SessionSchema
  alias Agents.Sessions.Infrastructure.Subscribers.TicketSessionTerminationHandler
  alias Agents.Tickets.Infrastructure.Schemas.ProjectTicketSchema

  setup :verify_on_exit!

  setup do
    original = Application.get_env(:agents, :ticket_session_terminator)

    on_exit(fn ->
      if original == nil do
        Application.delete_env(:agents, :ticket_session_terminator)
      else
        Application.put_env(:agents, :ticket_session_terminator, original)
      end
    end)

    :ok
  end

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

  defp insert_ticket(number, attrs) do
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

  test "ticket_closed event terminates linked session and unlinks ticket" do
    session = insert_session()
    _ticket = insert_ticket(700, %{session_id: session.id})

    Application.put_env(:agents, :ticket_session_terminator, fn ticket_number, _opts ->
      TerminateTicketSession.execute(ticket_number,
        container_provider: Agents.Mocks.ContainerProviderMock
      )
    end)

    Agents.Mocks.ContainerProviderMock
    |> expect(:remove, fn "ticket-container" -> :ok end)

    assert :ok =
             TicketSessionTerminationHandler.handle_event(%{
               event_type: "tickets.ticket_closed",
               number: 700
             })

    refreshed_session = Repo.get!(SessionSchema, session.id)
    refreshed_ticket = Repo.get_by!(ProjectTicketSchema, number: 700)

    assert refreshed_session.status == "terminated"
    assert refreshed_session.container_status == "removed"
    assert is_nil(refreshed_ticket.session_id)
  end

  test "pull_request_merged event terminates linked session and unlinks ticket" do
    session = insert_session(%{container_id: "pr-merge-container"})
    _ticket = insert_ticket(701, %{session_id: session.id})

    Application.put_env(:agents, :ticket_session_terminator, fn ticket_number, _opts ->
      TerminateTicketSession.execute(ticket_number,
        container_provider: Agents.Mocks.ContainerProviderMock
      )
    end)

    Agents.Mocks.ContainerProviderMock
    |> expect(:remove, fn "pr-merge-container" -> :ok end)

    assert :ok =
             TicketSessionTerminationHandler.handle_event(%{
               event_type: "pipeline.pull_request_merged",
               linked_ticket: 701
             })

    refreshed_session = Repo.get!(SessionSchema, session.id)
    refreshed_ticket = Repo.get_by!(ProjectTicketSchema, number: 701)

    assert refreshed_session.status == "terminated"
    assert refreshed_session.container_status == "removed"
    assert is_nil(refreshed_ticket.session_id)
  end
end
