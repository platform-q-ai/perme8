defmodule Jarga.Chat.Application.UseCases.DeleteMessage do
  @moduledoc """
  Deletes a chat message from a session.

  This use case handles removing individual messages from chat sessions,
  verifying ownership through the session's user_id.

  ## Examples

      iex> DeleteMessage.execute(message_id, user_id)
      {:ok, %ChatMessage{}}

      iex> DeleteMessage.execute(invalid_id, user_id)
      {:error, :not_found}
  """

  @default_session_repository Jarga.Chat.Infrastructure.Repositories.SessionRepository
  @default_message_repository Jarga.Chat.Infrastructure.Repositories.MessageRepository

  @doc """
  Deletes a message by ID, verifying the user owns the session.

  ## Parameters
    - message_id: ID of the message to delete
    - user_id: ID of the user requesting deletion
    - opts: Keyword list of options
      - :session_repository - Repository module for session operations (default: SessionRepository)
      - :message_repository - Repository module for message operations (default: MessageRepository)

  Returns `{:ok, message}` if successful, or `{:error, :not_found}` if not found
  or user doesn't own the session.
  """
  def execute(message_id, user_id, opts \\ []) do
    session_repository = Keyword.get(opts, :session_repository, @default_session_repository)
    message_repository = Keyword.get(opts, :message_repository, @default_message_repository)

    case session_repository.get_message_by_id_and_user(message_id, user_id) do
      nil -> {:error, :not_found}
      message -> message_repository.delete_message(message)
    end
  end
end
