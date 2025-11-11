defmodule Jarga.Agents.UseCases.ListSessions do
  @moduledoc """
  Lists chat sessions for a user with metadata.

  Returns sessions ordered by most recent first, with message count
  and preview of the first message.

  ## Clean Architecture
  This use case orchestrates infrastructure (Queries, Repo) without
  containing direct query logic. All queries are delegated to the
  Queries module as per ARCHITECTURE.md guidelines.

  ## Examples

      iex> ListSessions.execute(user_id)
      {:ok, [%{id: ..., title: "...", message_count: 5, preview: "..."}]}
  """

  alias Jarga.Agents.Infrastructure.SessionRepository

  @default_limit 50
  @preview_max_length 100

  @doc """
  Lists chat sessions for a user.

  ## Parameters
    - user_id: The ID of the user
    - opts: Options keyword list
      - :limit - Maximum number of sessions to return (default: 50)

  Returns `{:ok, sessions}` with list of session maps including:
    - id, title, inserted_at, updated_at
    - message_count - number of messages in the session
    - preview - first message content (truncated to 100 chars)
  """
  def execute(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)

    sessions =
      user_id
      |> SessionRepository.list_user_sessions(limit)
      |> Enum.map(&add_preview/1)

    {:ok, sessions}
  end

  defp add_preview(session) do
    # Get the first message for preview using Repository
    preview =
      session.id
      |> SessionRepository.get_first_message_content()
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
