defmodule Jarga.Documents.UseCases.ListSessions do
  @moduledoc """
  Lists chat sessions for a user with metadata.

  Returns sessions ordered by most recent first, with message count
  and preview of the first message.

  ## Examples

      iex> ListSessions.execute(user_id)
      {:ok, [%{id: ..., title: "...", message_count: 5, preview: "..."}]}
  """

  import Ecto.Query

  alias Jarga.Repo
  alias Jarga.Documents.ChatSession

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
      from(s in ChatSession,
        left_join: m in assoc(s, :messages),
        where: s.user_id == ^user_id,
        group_by: s.id,
        order_by: [desc: s.updated_at],
        limit: ^limit,
        select: %{
          id: s.id,
          title: s.title,
          inserted_at: s.inserted_at,
          updated_at: s.updated_at,
          message_count: count(m.id)
        }
      )
      |> Repo.all()
      |> Enum.map(&add_preview/1)

    {:ok, sessions}
  end

  defp add_preview(session) do
    # Get the first message for preview
    preview =
      from(m in Jarga.Documents.ChatMessage,
        where: m.chat_session_id == ^session.id,
        order_by: [asc: m.inserted_at],
        limit: 1,
        select: m.content
      )
      |> Repo.one()
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
