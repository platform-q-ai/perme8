defmodule Chat.Application.UseCases.LoadSession do
  @moduledoc """
  Loads a chat session with its messages.

  Supports paginated message loading via `message_limit` and `before_id` options.
  By default, loads the 50 most recent messages for the session.
  """

  @default_session_repository Chat.Infrastructure.Repositories.SessionRepository
  @default_message_limit 50

  def execute(session_id, opts \\ []) do
    session_repository = Keyword.get(opts, :session_repository, @default_session_repository)
    message_limit = Keyword.get(opts, :message_limit, @default_message_limit)

    pagination_opts = [message_limit: message_limit]

    case session_repository.get_session_by_id(session_id, pagination_opts) do
      nil -> {:error, :not_found}
      session -> {:ok, session}
    end
  end

  @doc """
  Loads older messages for a session using cursor-based pagination.

  Returns `{:ok, messages, has_more?}` where `has_more?` indicates whether
  there are still older messages available beyond this page.

  Uses the "limit + 1" trick: fetches one extra message to detect if more exist,
  then returns only the requested number.
  """
  def load_older_messages(session_id, before_id, opts \\ []) do
    session_repository = Keyword.get(opts, :session_repository, @default_session_repository)
    message_limit = Keyword.get(opts, :message_limit, @default_message_limit)

    messages =
      session_repository.load_messages(session_id,
        message_limit: message_limit + 1,
        before_id: before_id
      )

    has_more? = length(messages) > message_limit
    trimmed = if has_more?, do: Enum.take(messages, -message_limit), else: messages

    {:ok, trimmed, has_more?}
  end
end
