defmodule Chat.Application.UseCases.DeleteSession do
  @moduledoc """
  Deletes a chat session and all its messages.
  """

  alias Chat.Domain.Events.ChatSessionDeleted

  @default_session_repository Chat.Infrastructure.Repositories.SessionRepository
  @default_event_bus Perme8.Events.EventBus

  def execute(session_id, user_id, opts \\ []) do
    session_repository = Keyword.get(opts, :session_repository, @default_session_repository)
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)
    event_bus_opts = Keyword.get(opts, :event_bus_opts, [])

    case session_repository.get_session_by_id_and_user(session_id, user_id) do
      nil ->
        {:error, :not_found}

      session ->
        case session_repository.delete_session(session) do
          {:ok, deleted_session} ->
            emit_session_deleted_event(deleted_session, user_id, event_bus, event_bus_opts)
            {:ok, deleted_session}

          error ->
            error
        end
    end
  end

  defp emit_session_deleted_event(session, user_id, event_bus, event_bus_opts) do
    event =
      ChatSessionDeleted.new(%{
        aggregate_id: session.id,
        actor_id: user_id,
        session_id: session.id,
        user_id: user_id,
        workspace_id: session.workspace_id
      })

    event_bus.emit(event, event_bus_opts)
  end
end
