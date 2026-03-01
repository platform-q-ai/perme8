defmodule Chat.Application.UseCases.LoadSession do
  @moduledoc """
  Loads a chat session with its messages.
  """

  @default_session_repository Chat.Infrastructure.Repositories.SessionRepository

  def execute(session_id, opts \\ []) do
    session_repository = Keyword.get(opts, :session_repository, @default_session_repository)

    case session_repository.get_session_by_id(session_id) do
      nil -> {:error, :not_found}
      session -> {:ok, session}
    end
  end
end
