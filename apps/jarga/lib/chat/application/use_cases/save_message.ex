defmodule Jarga.Chat.Application.UseCases.SaveMessage do
  @moduledoc """
  Saves a chat message to a session.

  This use case handles persisting messages (both user and assistant)
  to the database within a chat session.

  ## Responsibilities
  - Create and persist message records
  - Validate message content and metadata
  - Associate messages with sessions

  ## Examples

      iex> SaveMessage.execute(%{
      ...>   chat_session_id: session.id,
      ...>   role: "user",
      ...>   content: "Hello!"
      ...> })
      {:ok, %ChatMessage{}}
  """

  @default_message_repository Jarga.Chat.Infrastructure.Repositories.MessageRepository

  @doc """
  Saves a new message to a chat session.

  ## Parameters
    - attrs: Map with the following keys:
      - chat_session_id: (required) ID of the chat session
      - role: (required) Either "user" or "assistant"
      - content: (required) Message content
      - context_chunks: (optional) Array of document chunk IDs used as context
    - opts: Keyword list of options
      - :message_repository - Repository module for message operations (default: MessageRepository)

  Returns `{:ok, message}` if successful, or `{:error, changeset}` if validation fails.
  """
  def execute(attrs, opts \\ []) do
    message_repository = Keyword.get(opts, :message_repository, @default_message_repository)
    message_repository.create_message(attrs)
  end
end
