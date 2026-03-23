defmodule Agents.Sessions.Application.UseCases.TerminateTicketSession do
  @moduledoc """
  Terminates a ticket-scoped session and unlinks it from the ticket.

  This is used by domain event subscribers when a ticket is closed or when
  its linked pull request is merged.
  """

  @default_container_provider Agents.Sessions.Infrastructure.Adapters.DockerAdapter
  @default_session_repo Application.compile_env(
                          :agents,
                          :session_repository,
                          Agents.Sessions.Infrastructure.Repositories.SessionRepository
                        )
  @default_ticket_repo Application.compile_env(
                         :agents,
                         :project_ticket_repository,
                         Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
                       )

  @spec execute(integer(), keyword()) :: :ok
  def execute(ticket_number, opts \\ []) when is_integer(ticket_number) do
    session_repo = Keyword.get(opts, :session_repo, @default_session_repo)
    ticket_repo = Keyword.get(opts, :ticket_repo, @default_ticket_repo)
    container_provider = Keyword.get(opts, :container_provider, @default_container_provider)

    case ticket_repo.get_by_number(ticket_number) do
      nil ->
        :ok

      {:ok, %{session_id: nil}} ->
        :ok

      {:ok, %{session_id: session_id}} when is_binary(session_id) ->
        terminate_linked_session(session_repo, container_provider, session_id)
        unlink_ticket_session(ticket_repo, ticket_number)
        :ok
    end
  end

  defp terminate_linked_session(session_repo, container_provider, session_id) do
    case session_repo.get_session(session_id) do
      nil ->
        :ok

      session ->
        maybe_remove_container(container_provider, session.container_id)

        _ =
          session_repo.update_session(session, %{
            status: "terminated",
            container_status: "removed",
            container_port: nil
          })

        :ok
    end
  end

  defp maybe_remove_container(_container_provider, nil), do: :ok

  defp maybe_remove_container(container_provider, container_id) do
    case container_provider.remove(container_id) do
      :ok -> :ok
      {:error, :not_found} -> :ok
      {:error, _reason} -> :ok
    end
  rescue
    _ -> :ok
  end

  defp unlink_ticket_session(ticket_repo, ticket_number) do
    _ = ticket_repo.unlink_session(ticket_number)
    :ok
  end
end
