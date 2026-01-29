defmodule Jarga.Chat.Application.UseCases.LoadSession do
  @moduledoc """
  Loads a chat session with its messages and relationships.

  This use case retrieves a chat session from the database along with
  all its messages (ordered chronologically) and related entities.

  ## Responsibilities
  - Load session by ID
  - Preload messages ordered by insertion time
  - Preload user, workspace, and project relationships
  - Return error if session not found

  ## Clean Architecture
  This use case orchestrates infrastructure (Queries, Repo) without
  containing direct query logic. All queries are delegated to the
  Queries module as per ARCHITECTURE.md guidelines.

  ## Examples

      iex> LoadSession.execute(session_id)
      {:ok, %ChatSession{messages: [%ChatMessage{}, ...]}}

      iex> LoadSession.execute(invalid_id)
      {:error, :not_found}
  """

  @default_session_repository Jarga.Chat.Infrastructure.Repositories.SessionRepository

  @doc """
  Loads a chat session with all its data.

  ## Parameters
    - session_id: The ID of the session to load
    - opts: Keyword list of options
      - :session_repository - Repository module for session operations (default: SessionRepository)

  Returns `{:ok, session}` with preloaded messages and relationships,
  or `{:error, :not_found}` if the session doesn't exist.
  """
  def execute(session_id, opts \\ []) do
    session_repository = Keyword.get(opts, :session_repository, @default_session_repository)

    case session_repository.get_session_by_id(session_id) do
      nil -> {:error, :not_found}
      session -> {:ok, session}
    end
  end
end
