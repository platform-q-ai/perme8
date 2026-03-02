defmodule Chat.Application.UseCases.ListSessions do
  @moduledoc """
  Lists chat sessions for a user with metadata.

  Uses a single batched query to fetch session previews,
  eliminating the N+1 query pattern.
  """

  @default_session_repository Chat.Infrastructure.Repositories.SessionRepository

  @default_limit 50
  @preview_max_length 100

  def execute(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)
    session_repository = Keyword.get(opts, :session_repository, @default_session_repository)

    sessions =
      user_id
      |> session_repository.list_user_sessions_with_preview(limit)
      |> Enum.map(&truncate_session_preview/1)

    {:ok, sessions}
  end

  defp truncate_session_preview(session) do
    Map.update(session, :preview, nil, &truncate_preview/1)
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
