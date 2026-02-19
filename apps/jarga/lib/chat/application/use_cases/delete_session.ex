defmodule Jarga.Chat.Application.UseCases.DeleteSession do
  @moduledoc """
  Deletes a chat session and all its messages.

  Only allows users to delete their own sessions (authorization check).

  ## Clean Architecture
  This use case orchestrates infrastructure (Queries, Repo) without
  containing direct query logic. All queries are delegated to the
  Queries module as per ARCHITECTURE.md guidelines.

  ## Examples

      iex> DeleteSession.execute(session_id, user_id)
      {:ok, %ChatSession{}}

      iex> DeleteSession.execute(invalid_id, user_id)
      {:error, :not_found}
  """

  alias Jarga.Chat.Domain.Events.ChatSessionDeleted

  @default_session_repository Jarga.Chat.Infrastructure.Repositories.SessionRepository
  @default_event_bus Perme8.Events.EventBus

  @doc """
  Deletes a chat session.

  ## Parameters
    - session_id: ID of the session to delete
    - user_id: ID of the user (for authorization)
    - opts: Keyword list of options
      - :session_repository - Repository module for session operations (default: SessionRepository)

  Returns `{:ok, deleted_session}` if successful,
  or `{:error, :not_found}` if session doesn't exist or user doesn't own it.

  Messages are automatically deleted via database cascade.
  """
  def execute(session_id, user_id, opts \\ []) do
    session_repository = Keyword.get(opts, :session_repository, @default_session_repository)
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)

    case session_repository.get_session_by_id_and_user(session_id, user_id) do
      nil ->
        {:error, :not_found}

      session ->
        case session_repository.delete_session(session) do
          {:ok, deleted_session} ->
            emit_session_deleted_event(deleted_session, user_id, event_bus)
            {:ok, deleted_session}

          error ->
            error
        end
    end
  end

  defp emit_session_deleted_event(session, user_id, event_bus) do
    event =
      ChatSessionDeleted.new(%{
        aggregate_id: session.id,
        actor_id: user_id,
        session_id: session.id,
        user_id: user_id,
        workspace_id: session.workspace_id
      })

    event_bus.emit(event)
  end
end
