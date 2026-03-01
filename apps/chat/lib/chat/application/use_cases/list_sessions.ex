defmodule Chat.Application.UseCases.ListSessions do
  @moduledoc """
  Lists chat sessions for a user with metadata.
  """

  @default_session_repository Chat.Infrastructure.Repositories.SessionRepository

  @default_limit 50
  @preview_max_length 100

  def execute(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)
    session_repository = Keyword.get(opts, :session_repository, @default_session_repository)

    sessions =
      user_id
      |> session_repository.list_user_sessions(limit)
      |> Enum.map(&add_preview(&1, session_repository))

    {:ok, sessions}
  end

  defp add_preview(session, session_repository) do
    preview =
      session.id
      |> session_repository.get_first_message_content()
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
