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

  alias Jarga.Chat.Domain.Events.ChatMessageSent

  @default_message_repository Jarga.Chat.Infrastructure.Repositories.MessageRepository
  @default_session_repository Jarga.Chat.Infrastructure.Repositories.SessionRepository
  @default_event_bus Perme8.Events.EventBus

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
    session_repository = Keyword.get(opts, :session_repository, @default_session_repository)
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)

    case message_repository.create_message(attrs) do
      {:ok, message} ->
        emit_message_sent_event(message, attrs, session_repository, event_bus)
        {:ok, message}

      error ->
        error
    end
  end

  defp emit_message_sent_event(message, _attrs, session_repository, event_bus) do
    session = session_repository.get_session_by_id(message.chat_session_id)

    if session do
      event =
        ChatMessageSent.new(%{
          aggregate_id: message.id,
          actor_id: session.user_id,
          message_id: message.id,
          session_id: message.chat_session_id,
          user_id: session.user_id,
          role: message.role,
          workspace_id: session.workspace_id
        })

      event_bus.emit(event)
    end
  end
end
