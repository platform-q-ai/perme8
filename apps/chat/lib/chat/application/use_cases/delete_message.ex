defmodule Chat.Application.UseCases.DeleteMessage do
  @moduledoc """
  Deletes a chat message from a session.
  """

  @default_session_repository Chat.Infrastructure.Repositories.SessionRepository
  @default_message_repository Chat.Infrastructure.Repositories.MessageRepository

  def execute(message_id, user_id, opts \\ []) do
    session_repository = Keyword.get(opts, :session_repository, @default_session_repository)
    message_repository = Keyword.get(opts, :message_repository, @default_message_repository)

    case session_repository.get_message_by_id_and_user(message_id, user_id) do
      nil -> {:error, :not_found}
      message -> message_repository.delete_message(message)
    end
  end
end
