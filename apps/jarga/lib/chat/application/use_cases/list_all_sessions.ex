defmodule Jarga.Chat.Application.UseCases.ListAllSessions do
  @moduledoc """
  Lists all chat sessions across all users with metadata.

  Returns sessions ordered by most recent first, with message count
  and preview of the first message. Unlike `ListSessions`, this use case
  does not filter by user — it returns all sessions in the system.

  Intended for admin/dashboard views (e.g., Perme8 Dashboard) where
  a global view of chat sessions is needed.

  ## Clean Architecture
  This use case orchestrates infrastructure (Queries, Repo) without
  containing direct query logic. All queries are delegated to the
  Queries module as per ARCHITECTURE.md guidelines.

  ## Examples

      iex> ListAllSessions.execute()
      {:ok, [%{id: ..., title: "...", message_count: 5, preview: "..."}]}

      iex> ListAllSessions.execute(limit: 10)
      {:ok, [%{id: ..., title: "...", message_count: 3, preview: "..."}]}
  """

  @default_session_repository Jarga.Chat.Infrastructure.Repositories.SessionRepository

  @default_limit 50
  @preview_max_length 100

  @doc """
  Lists all chat sessions across all users.

  ## Parameters
    - opts: Options keyword list
      - :limit - Maximum number of sessions to return (default: 50)
      - :session_repository - Repository module for session operations (default: SessionRepository)

  Returns `{:ok, sessions}` with list of session maps including:
    - id, title, inserted_at, updated_at
    - message_count - number of messages in the session
    - preview - first message content (truncated to 100 chars)
  """
  def execute(opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)
    session_repository = Keyword.get(opts, :session_repository, @default_session_repository)

    sessions = session_repository.list_all_sessions(limit)

    previews =
      sessions
      |> Enum.map(& &1.id)
      |> session_repository.get_first_message_contents()

    sessions = Enum.map(sessions, &add_preview(&1, previews))

    {:ok, sessions}
  end

  defp add_preview(session, previews) do
    preview =
      previews
      |> Map.get(session.id)
      |> truncate_preview()

    Map.put(session, :preview, preview)
  end

  defp truncate_preview(nil), do: nil

  defp truncate_preview(content) when is_binary(content) do
    if String.length(content) > @preview_max_length do
      String.slice(content, 0, @preview_max_length) <> "..."
    else
      content
    end
  end
end
